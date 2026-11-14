import SwiftUI
import Observation

@MainActor
@Observable
final class SpeakingViewModel {
    var language: CardLanguage = .english
    var practice: SpeakingPractice?
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        language = newLanguage
        if !isGenerating {
            practice = nil
            errorMessage = nil
        }
    }

    func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        practice = nil
        let lang = language

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.speaking(language: lang) {
                    acc += chunk
                }
                if let parsed = PracticeParsing.speaking(from: acc) {
                    practice = parsed
                    Haptics.notify(.success)
                } else {
                    errorMessage = "Không tạo được nội dung, thử lại"
                    Haptics.notify(.error)
                }
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
            }
            isGenerating = false
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
                    ProgressView("Đang tạo…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let practice = vm.practice {
                    SpeakingContentView(practice: practice, language: vm.language)
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
    }
}

private struct SpeakingContentView: View {
    let practice: SpeakingPractice
    let language: CardLanguage

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
                Button {
                    play(passageText)
                } label: {
                    Label("Phát âm toàn bài", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.green)
            }

            ForEach(Array(practice.sentences.enumerated()), id: \.element.id) { index, sentence in
                SpeakingSentenceCard(sentence: sentence, number: index + 1, language: language)
            }
        }
    }

    private func play(_ text: String) {
        Haptics.impact(.light)
        let effectiveLang: CardLanguage = text.hasChineseCharacters ? .chinese : language
        Task { @MainActor in
            try? await TTSService().speak(text, language: effectiveLang)
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
                    .font(effectiveLang == .chinese ? VocaTypography.hanziFont(size: 19, weight: .medium) : .body)
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
