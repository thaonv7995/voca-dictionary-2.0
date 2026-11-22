import SwiftUI
import Observation

@MainActor
@Observable
final class SpeakingViewModel {
    var language: CardLanguage = .english
    var practice: SpeakingPractice?
    var isGenerating = false
    var errorMessage: String?
    var isPlayingPassage = false
    var playbackError: String?

    private let service = AssistantService()
    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var requestGeneration = 0

    deinit {
        generateTask?.cancel()
        playbackTask?.cancel()
    }

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        cancelGeneration()
        stopPlayback()
        language = newLanguage
        practice = nil
        errorMessage = nil
    }

    func cancelGeneration() {
        requestGeneration &+= 1
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        if isPlayingPassage {
            AudioPlayer.shared.stop()
        }
        isPlayingPassage = false
    }

    func togglePlayPassage(_ text: String) {
        if isPlayingPassage {
            stopPlayback()
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Haptics.impact(.light)
        playbackError = nil
        isPlayingPassage = true
        let effectiveLang: CardLanguage = trimmed.hasChineseCharacters ? .chinese : language
        playbackTask = Task { @MainActor [weak self] in
            do {
                _ = try await TTSService().speakAndWait(trimmed, language: effectiveLang)
            } catch is CancellationError {
                // Stopped by user
            } catch {
                self?.playbackError = (error as? ApiError)?.message ?? error.localizedDescription
            }
            if !Task.isCancelled {
                self?.isPlayingPassage = false
                self?.playbackTask = nil
            }
        }
    }

    func generate() {
        guard !isGenerating else { return }
        stopPlayback()
        requestGeneration &+= 1
        let expectedGen = requestGeneration
        isGenerating = true
        errorMessage = nil
        playbackError = nil
        practice = nil
        let lang = language

        generateTask?.cancel()
        generateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var acc = ""
            do {
                for try await chunk in service.speaking(language: lang) {
                    if Task.isCancelled || self.requestGeneration != expectedGen { return }
                    acc += chunk
                }
                guard !Task.isCancelled, self.requestGeneration == expectedGen else { return }
                if let parsed = PracticeParsing.speaking(from: acc) {
                    practice = parsed
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
}

/// Generates a speaking practice with wrapped word IPA/Pinyin chips and per-sentence TTS.
struct SpeakingView: View {
    @Bindable var vm: SpeakingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    Haptics.impact(.light)
                    vm.generate()
                } label: {
                    Label(vm.practice == nil ? "Tạo bài luyện nói" : "Tạo bài luyện nói mới",
                          systemImage: "waveform")
                }
                .buttonStyle(BrandCTAButtonStyle())
                .disabled(vm.isGenerating)

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

                if let practice = vm.practice {
                    SpeakingContentView(
                        practice: practice,
                        language: vm.language,
                        isPlayingPassage: vm.isPlayingPassage,
                        playbackError: vm.playbackError,
                        onTogglePlayPassage: { vm.togglePlayPassage($0) }
                    )
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    VStack(spacing: 12) {
                        VocaIconBadge(systemImage: "waveform", size: 54, iconSize: 24)
                        Text(vm.language == .chinese
                             ? "Nhấn nút để tạo bài luyện nói tiếng Trung kèm Pinyin và phát âm mẫu."
                             : "Nhấn nút để tạo một bài luyện nói kèm phiên âm và phát âm mẫu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                }
            }
            .padding()
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .onDisappear { vm.stopPlayback() }
    }
}

private struct SpeakingContentView: View {
    let practice: SpeakingPractice
    let language: CardLanguage
    let isPlayingPassage: Bool
    let playbackError: String?
    let onTogglePlayPassage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = practice.title, !title.isEmpty {
                Text(title).font(.title3).bold()
            }
            if let topic = practice.topic, !topic.isEmpty {
                Badge(text: topic)
            }

            if let passageText = practice.passageText,
               !passageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        onTogglePlayPassage(passageText)
                    } label: {
                        HStack(spacing: 8) {
                            if isPlayingPassage {
                                ProgressView().controlSize(.small).tint(.white)
                            }
                            Label(
                                isPlayingPassage ? "Dừng phát toàn bài" : "Phát âm toàn bài",
                                systemImage: isPlayingPassage ? "stop.circle.fill" : "play.circle.fill"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isPlayingPassage ? Color.red : Brand.green)

                    if let playbackError {
                        Text(playbackError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            ForEach(Array(practice.sentences.enumerated()), id: \.element.id) { index, sentence in
                SpeakingSentenceCard(sentence: sentence, number: index + 1, language: language)
            }
        }
    }
}

private struct SpeakingSentenceCard: View {
    let sentence: SpeakingSentence
    let number: Int
    let language: CardLanguage

    var body: some View {
        let sentenceText = sentence.text ?? ""
        let effectiveLang: CardLanguage = sentenceText.hasChineseCharacters ? .chinese : language
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.subheadline).bold()
                    .foregroundStyle(Brand.green)
                Text(sentenceText)
                    .font(effectiveLang == .chinese ? VocaTypography.hanziFont(size: 19, weight: .medium, isCalligraphic: ThemeStore.shared.hanziCalligraphic) : .body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                PronounceButton(text: sentenceText, language: effectiveLang, tintedCapsule: true)
            }

            if let ipa = sentence.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let words = sentence.words, !words.isEmpty {
                FlowChips(words: words)
            }

            if let links = sentence.connectedSpeech, !links.isEmpty {
                connectedSpeechRow(links)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func connectedSpeechRow(_ links: [ConnectedSpeech]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(.secondary)
            VocaFlowLayout(spacing: 6) {
                ForEach(links) { link in
                    let label = [link.from, link.symbol ?? link.type, link.to]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    if !label.isEmpty {
                        Text(label).chip()
                    }
                }
            }
        }
    }
}

private struct FlowChips: View {
    let words: [SpeakingWord]

    var body: some View {
        VocaFlowLayout(spacing: 6) {
            ForEach(words) { word in
                WordIPAChip(word: word.word ?? "", ipa: word.ipa)
            }
        }
    }
}
