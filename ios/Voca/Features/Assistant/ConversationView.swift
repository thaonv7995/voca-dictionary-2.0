import SwiftUI
import Observation

/// Generates and holds a listening/conversation passage (`daily_conversation`),
/// and drives sequential "play all" TTS playback across its lines.
@MainActor
@Observable
final class ConversationViewModel {
    var format: ConversationFormat = .auto
    var conversation: Conversation?
    var isGenerating = false
    var errorMessage: String?
    var isPlayingAll = false

    private let service = AssistantService()
    private let tts = TTSService()
    private var playAllTask: Task<Void, Never>?

    /// Streams the conversation JSON, accumulates, then parses it into a `Conversation`.
    func generate() {
        guard !isGenerating else { return }
        stopPlayAll()
        isGenerating = true
        errorMessage = nil
        conversation = nil
        let fmt = format

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.conversation(format: fmt.rawValue) {
                    acc += chunk
                }
                if let parsed = PracticeParsing.conversation(from: acc) {
                    conversation = parsed
                } else {
                    errorMessage = "Không tạo được nội dung, thử lại"
                }
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isGenerating = false
        }
    }

    /// Voice model for a line's speaker (nil → server default voice).
    func voice(for line: ConversationLine) -> String? {
        conversation?.voiceAssignments?[line.speaker ?? ""]
    }

    func togglePlayAll() {
        isPlayingAll ? stopPlayAll() : startPlayAll()
    }

    /// Plays every line in order, waiting for each clip to finish before the next.
    private func startPlayAll() {
        guard let lines = conversation?.lines, !lines.isEmpty else { return }
        isPlayingAll = true
        playAllTask = Task { @MainActor in
            for line in lines {
                if Task.isCancelled { break }
                let text = (line.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                do {
                    try await tts.speakAndWait(text, voiceModel: voice(for: line))
                } catch {
                    break // e.g. TTS not configured (503) — stop the run quietly
                }
                if Task.isCancelled { break }
            }
            // A cancelled run is cleaned up by stopPlayAll(); only a natural finish
            // resets state here to avoid clobbering a freshly started run.
            if !Task.isCancelled {
                isPlayingAll = false
                playAllTask = nil
            }
        }
    }

    private func stopPlayAll() {
        playAllTask?.cancel()
        playAllTask = nil
        AudioPlayer.shared.stop() // resumes any pending speakAndWait continuation
        isPlayingAll = false
    }
}

/// Picks a format, generates a listening passage, and renders it as chat bubbles
/// with vocabulary highlighting, per-line TTS and a sequential "play all".
struct ConversationView: View {
    @Bindable var vm: ConversationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls

                if vm.isGenerating {
                    ProgressView("Đang tạo…")
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
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Định dạng")
                    .font(.subheadline)
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
        VStack(spacing: 8) {
            Image(systemName: "person.2.wave.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Chưa có hội thoại, nhấn Tạo")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: Content

    private func conversationContent(_ c: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            headerCard(c)
            playbackRow

            let speakers = orderedSpeakers(c)
            ForEach(c.lines) { line in
                ConversationBubble(
                    line: line,
                    isPrimary: isPrimary(line, speakers: speakers),
                    attributed: highlightedVocabulary(line.text ?? "", vocabulary: line.vocabulary),
                    voiceModel: vm.voice(for: line))
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
        .brandCard()
    }

    private var playbackRow: some View {
        HStack {
            Button {
                vm.togglePlayAll()
            } label: {
                Label(vm.isPlayingAll ? "Dừng" : "Phát tất cả",
                      systemImage: vm.isPlayingAll ? "stop.circle.fill" : "play.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(Brand.green)

            Spacer()

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

    // MARK: Helpers

    /// Human label for the conversation's format, falling back to the selected one.
    private func formatLabel(_ c: Conversation) -> String {
        if let raw = c.format?.lowercased(),
           let known = ConversationFormat(rawValue: raw) {
            return known.label
        }
        if let raw = c.format, !raw.isEmpty { return raw }
        return vm.format.label
    }

    /// Speakers in first-appearance order (prefers the declared list).
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

    /// Left-align the primary (first) speaker; right-align everyone else. With 0–1
    /// distinct speakers (story / announcement) every line stays on the left.
    private func isPrimary(_ line: ConversationLine, speakers: [String]) -> Bool {
        guard speakers.count > 1 else { return true }
        return (line.speaker ?? "") == speakers.first
    }
}

// MARK: - Bubble

/// One chat bubble: avatar, speaker name + speaker button, the English text with its
/// vocabulary highlighted, the Vietnamese translation, and any vocabulary glosses.
private struct ConversationBubble: View {
    let line: ConversationLine
    let isPrimary: Bool
    let attributed: AttributedString
    let voiceModel: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isPrimary {
                avatar
                bubble
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
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
                PronounceButton(text: line.text ?? "", voiceModel: voiceModel, size: 24, font: .footnote)
            }

            if let text = line.text, !text.isEmpty {
                Text(attributed)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let glosses = vocabularyGlosses
            if !glosses.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
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
        .padding(12)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .background(Brand.green, in: Circle())
    }

    private var bubbleColor: Color {
        isPrimary ? Color(.secondarySystemBackground) : Brand.greenSoft
    }

    /// First letter of the speaker name, or nil for narration (no speaker).
    private var initial: String? {
        let s = (line.speaker ?? "").trimmingCharacters(in: .whitespaces)
        guard let first = s.first else { return nil }
        return String(first).uppercased()
    }

    /// Ordered vocabulary terms that have a Vietnamese gloss.
    private var vocabularyGlosses: [Gloss] {
        guard let meanings = line.vocabularyMeanings, !meanings.isEmpty else { return [] }
        let order = line.vocabulary ?? Array(meanings.keys)
        return order.compactMap { term in
            guard let meaning = meanings[term], !meaning.isEmpty else { return nil }
            return Gloss(term: term, meaning: meaning)
        }
    }
}

/// A single vocabulary term paired with its Vietnamese gloss.
private struct Gloss: Identifiable {
    let term: String
    let meaning: String
    var id: String { term }
}

// MARK: - Vocabulary highlighting

/// Builds an `AttributedString` from `text`, styling every (case-insensitive)
/// occurrence of each vocabulary term in green + semibold.
private func highlightedVocabulary(_ text: String, vocabulary: [String]?) -> AttributedString {
    var result = AttributedString(text)
    guard let vocabulary, !vocabulary.isEmpty, !text.isEmpty else { return result }

    for raw in vocabulary {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { continue }

        var searchStart = result.startIndex
        while searchStart < result.endIndex,
              let found = result[searchStart..<result.endIndex]
                .range(of: term, options: .caseInsensitive) {
            result[found].foregroundColor = Brand.green
            result[found].font = .body.weight(.semibold)
            searchStart = found.upperBound
        }
    }
    return result
}
