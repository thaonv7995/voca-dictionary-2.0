import SwiftUI
import Observation

/// Generates and holds a listening/conversation passage and drives highlighted sequential TTS playback.
@MainActor
@Observable
final class ConversationViewModel {
    var language: CardLanguage = .english
    var format: ConversationFormat = .auto
    var conversation: Conversation?
    var isGenerating = false
    var errorMessage: String?
    var isPlayingAll = false
    var activeLineID: UUID?

    private let service = AssistantService()
    private let tts = TTSService()
    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var playAllTask: Task<Void, Never>?
    @ObservationIgnored private var requestGeneration = 0

    deinit {
        generateTask?.cancel()
        playAllTask?.cancel()
    }

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        cancelGeneration()
        stopPlayAll()
        language = newLanguage
        conversation = nil
        errorMessage = nil
    }

    func cancelGeneration() {
        requestGeneration &+= 1
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    func generate() {
        guard !isGenerating else { return }
        stopPlayAll()
        requestGeneration &+= 1
        let expectedGen = requestGeneration
        isGenerating = true
        errorMessage = nil
        conversation = nil
        let fmt = format
        let lang = language

        generateTask?.cancel()
        generateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await VoiceSettingsStore.shared.refreshIfNeeded()
            guard !Task.isCancelled, self.requestGeneration == expectedGen else { return }
            let availableVoices = VoiceSettingsStore.shared.availableVoiceOptions(for: lang)
            let autoSelect = VoiceSettingsStore.shared.autoSelectConversationVoices

            var acc = ""
            do {
                for try await chunk in service.conversation(
                    format: fmt.rawValue,
                    language: lang,
                    availableVoices: availableVoices,
                    autoSelectVoices: autoSelect
                ) {
                    if Task.isCancelled || self.requestGeneration != expectedGen { return }
                    acc += chunk
                }
                guard !Task.isCancelled, self.requestGeneration == expectedGen else { return }
                if let parsed = PracticeParsing.conversation(from: acc) {
                    conversation = parsed
                    Haptics.notify(.success)
                } else {
                    errorMessage = "Không tạo được nội dung, thử lại"
                    Haptics.notify(.error)
                }
            } catch is CancellationError {
                return
            } catch {
                guard self.requestGeneration == expectedGen else { return }
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
            }
            if self.requestGeneration == expectedGen {
                isGenerating = false
                generateTask = nil
            }
        }
    }

    func language(for line: ConversationLine) -> CardLanguage {
        (line.text?.hasChineseCharacters == true) ? .chinese : language
    }

    func voice(for line: ConversationLine) -> String? {
        let lineLanguage = language(for: line)
        let speaker = (line.speaker ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if VoiceSettingsStore.shared.autoSelectConversationVoices,
           !speaker.isEmpty,
           let assigned = conversation?.voiceAssignments?[speaker]?
               .trimmingCharacters(in: .whitespacesAndNewlines),
           !assigned.isEmpty,
           !(lineLanguage == .chinese && VoiceSettingsStore.isEnglishVoice(assigned)),
           !(lineLanguage == .english && VoiceSettingsStore.isChineseVoice(assigned)) {
            return assigned
        }

        let pool = VoiceSettingsStore.shared.speakerVoices(for: lineLanguage)
        guard !pool.isEmpty else { return nil }
        let speakers = orderedSpeakerNames()
        let index = speakers.firstIndex(of: speaker) ?? 0
        return pool[index % pool.count]
    }

    private func orderedSpeakerNames() -> [String] {
        var seen: [String] = []
        for name in conversation?.speakers ?? [] {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !seen.contains(trimmed) { seen.append(trimmed) }
        }
        for line in conversation?.lines ?? [] {
            let trimmed = (line.speaker ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !seen.contains(trimmed) { seen.append(trimmed) }
        }
        return seen
    }

    func togglePlayAll() {
        isPlayingAll ? stopPlayAll() : startPlayAll()
    }

    private func startPlayAll() {
        guard let lines = conversation?.lines, !lines.isEmpty else { return }
        isPlayingAll = true
        playAllTask?.cancel()
        playAllTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for line in lines {
                if Task.isCancelled { break }
                let text = (line.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                self.activeLineID = line.id
                do {
                    let completed = try await self.tts.speakAndWait(
                        text,
                        language: self.language(for: line),
                        voiceModel: self.voice(for: line)
                    )
                    if !completed {
                        // Interrupted by user Stop or single-line playback — stop advancing.
                        break
                    }
                } catch is CancellationError {
                    break
                } catch {
                    self.errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                    break
                }
                if Task.isCancelled { break }
            }
            if !Task.isCancelled {
                self.isPlayingAll = false
                self.activeLineID = nil
                self.playAllTask = nil
            }
        }
    }

    func stopPlayAll() {
        playAllTask?.cancel()
        playAllTask = nil
        if isPlayingAll {
            AudioPlayer.shared.stop()
        }
        isPlayingAll = false
        activeLineID = nil
    }
}

/// Interactive listening/dialogue studio with active-line highlight and Pinyin/Translation blind-listening toggles.
struct ConversationView: View {
    @Bindable var vm: ConversationViewModel
    @State private var showPinyin = true
    @State private var showTranslation = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls

                    if vm.isGenerating {
                        VStack(spacing: 10) {
                            ProgressView("Đang tạo…")
                            Button("Dừng", role: .destructive) { vm.cancelGeneration() }
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let conversation = vm.conversation {
                        conversationContent(conversation)
                    } else if !vm.isGenerating && vm.errorMessage == nil {
                        emptyState
                    }
                }
                .padding()
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: vm.activeLineID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .onDisappear { vm.stopPlayAll() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Định dạng")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Định dạng", selection: $vm.format) {
                    ForEach(ConversationFormat.allCases) { fmt in
                        Text(fmt.label).tag(fmt)
                    }
                }
                .pickerStyle(.menu)
                .tint(Brand.green)
                .disabled(vm.isGenerating)
            }

            Button {
                Haptics.impact(.light)
                vm.generate()
            } label: {
                Label(vm.conversation == nil ? "Tạo hội thoại" : "Tạo hội thoại mới",
                      systemImage: "person.2.wave.2")
            }
            .buttonStyle(BrandCTAButtonStyle())
            .disabled(vm.isGenerating)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            VocaIconBadge(systemImage: "person.2.wave.2", size: 54, iconSize: 24)
            Text(vm.language == .chinese
                 ? "Chưa có hội thoại tiếng Trung, nhấn Tạo hội thoại"
                 : "Chưa có hội thoại, nhấn Tạo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }

    private func conversationContent(_ c: Conversation) -> some View {
        let hasAnyPinyin = c.lines.contains { !($0.pinyin ?? "").isEmpty }

        return VStack(alignment: .leading, spacing: 12) {
            headerCard(c)
            playbackRow(hasAnyPinyin: hasAnyPinyin)

            let speakers = orderedSpeakers(c)
            ForEach(c.lines) { line in
                let lineLang = vm.language(for: line)
                ConversationBubble(
                    line: line,
                    isPrimary: isPrimary(line, speakers: speakers),
                    isActive: vm.activeLineID == line.id,
                    showPinyin: showPinyin,
                    showTranslation: showTranslation,
                    attributed: highlightedVocabulary(line.text ?? "", vocabulary: line.vocabulary, language: lineLang),
                    voiceModel: vm.voice(for: line),
                    language: lineLang)
                .id(line.id)
            }
        }
    }

    private func headerCard(_ c: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = c.title, !title.isEmpty {
                Text(title).font(.title3).bold()
            }
            HStack(spacing: 6) {
                Badge(text: formatLabel(c))
                if let count = c.speakers?.count, count > 0 {
                    Badge(text: "\(count) người", color: .secondary)
                }
            }
            if let context = c.context, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandHeroCard(padding: 16, cornerRadius: 18)
    }

    private func playbackRow(hasAnyPinyin: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact(.light)
                    vm.togglePlayAll()
                } label: {
                    Label(vm.isPlayingAll ? "Dừng" : "Phát tất cả",
                          systemImage: vm.isPlayingAll ? "stop.circle.fill" : "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.green)

                if hasAnyPinyin {
                    visibilityChip(title: "Pinyin", isOn: $showPinyin)
                }

                visibilityChip(title: "Dịch nghĩa", isOn: $showTranslation)

                Button {
                    vm.generate()
                } label: {
                    Label("Tạo lại", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(Brand.green)
                .disabled(vm.isGenerating)
            }
        }
    }

    private func visibilityChip(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.16)) { isOn.wrappedValue.toggle() }
        } label: {
            Label(title, systemImage: isOn.wrappedValue ? "eye.fill" : "eye.slash")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .foregroundStyle(isOn.wrappedValue ? Brand.green : .secondary)
                .background(isOn.wrappedValue ? Brand.greenSoft : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formatLabel(_ c: Conversation) -> String {
        if let raw = c.format?.lowercased(),
           let known = ConversationFormat(rawValue: raw) {
            return known.label
        }
        if let raw = c.format, !raw.isEmpty { return raw }
        return vm.format.label
    }

    private func orderedSpeakers(_ c: Conversation) -> [String] {
        if let declared = c.speakers?.filter({ !$0.isEmpty }), !declared.isEmpty {
            return declared
        }
        var seen: [String] = []
        for line in c.lines {
            if let sp = line.speaker, !sp.isEmpty, !seen.contains(sp) { seen.append(sp) }
        }
        return seen
    }

    private func isPrimary(_ line: ConversationLine, speakers: [String]) -> Bool {
        guard speakers.count > 1 else { return true }
        return (line.speaker ?? "") == speakers.first
    }
}

private struct ConversationBubble: View {
    @Environment(\.colorScheme) private var colorScheme

    let line: ConversationLine
    let isPrimary: Bool
    let isActive: Bool
    let showPinyin: Bool
    let showTranslation: Bool
    let attributed: AttributedString
    let voiceModel: String?
    let language: CardLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isPrimary {
                avatar
                bubble
                Spacer(minLength: 20)
            } else {
                Spacer(minLength: 20)
                bubble
                avatar
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let speaker = line.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if isActive {
                    VocaPillBadge(text: "Đang phát", icon: "waveform")
                }
                Spacer(minLength: 0)
                PronounceButton(
                    text: line.text ?? "",
                    voiceModel: voiceModel,
                    language: language,
                    size: 26,
                    font: .footnote,
                    tintedCapsule: true
                )
            }

            if let text = line.text, !text.isEmpty {
                Text(attributed)
                    .font(language == .chinese ? VocaTypography.hanziFont(size: 18, weight: .medium, isCalligraphic: ThemeStore.shared.hanziCalligraphic) : .body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showPinyin, let pinyin = line.pinyin, !pinyin.isEmpty {
                Text(pinyin)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Brand.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showTranslation, let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let glosses = vocabularyGlosses
            if !glosses.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(glosses) { item in
                        (Text(item.term).foregroundColor(Brand.green).fontWeight(.semibold)
                            + Text(" — \(item.meaning)").foregroundColor(.secondary))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isActive ? Brand.green : Brand.hairlineBorder(for: colorScheme),
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(color: isActive ? Brand.green.opacity(0.20) : .clear, radius: 10, y: 3)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    @ViewBuilder private var avatar: some View {
        Group {
            if let letter = initial {
                Text(letter).font(.subheadline.weight(.bold))
            } else {
                Image(systemName: "quote.bubble.fill").font(.footnote)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 32, height: 32)
        .background(Brand.gradient, in: Circle())
    }

    private var bubbleColor: Color {
        isPrimary ? Brand.cardFill(for: colorScheme) : Brand.greenSoft
    }

    private var initial: String? {
        let s = (line.speaker ?? "").trimmingCharacters(in: .whitespaces)
        guard let first = s.first else { return nil }
        return String(first).uppercased()
    }

    private var vocabularyGlosses: [Gloss] {
        guard let meanings = line.vocabularyMeanings, !meanings.isEmpty else { return [] }
        let order = line.vocabulary ?? Array(meanings.keys)
        return order.compactMap { term in
            guard let meaning = meanings[term], !meaning.isEmpty else { return nil }
            return Gloss(term: term, meaning: meaning)
        }
    }
}

private struct Gloss: Identifiable {
    let term: String
    let meaning: String
    var id: String { term }
}

@MainActor
private func highlightedVocabulary(_ text: String, vocabulary: [String]?, language: CardLanguage) -> AttributedString {
    var result = AttributedString(text)
    guard let vocabulary, !vocabulary.isEmpty, !text.isEmpty else { return result }
    let highlightFont: Font = language == .chinese
        ? VocaTypography.hanziFont(size: 18, weight: .bold, isCalligraphic: ThemeStore.shared.hanziCalligraphic)
        : .body.weight(.semibold)

    for raw in vocabulary {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { continue }

        var searchStart = result.startIndex
        while searchStart < result.endIndex,
              let found = result[searchStart..<result.endIndex]
                .range(of: term, options: .caseInsensitive) {
            result[found].foregroundColor = Brand.green
            result[found].font = highlightFont
            searchStart = found.upperBound
        }
    }
    return result
}
