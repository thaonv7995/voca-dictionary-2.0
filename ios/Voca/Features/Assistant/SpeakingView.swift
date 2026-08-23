import SwiftUI
import Observation

/// Generates and holds a shadowing/speaking passage (per-sentence text + IPA + word timings).
@MainActor
@Observable
final class SpeakingViewModel {
    var practice: SpeakingPractice?
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()

    func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        practice = nil

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.speaking() {
                    acc += chunk
                }
                if let parsed = PracticeParsing.speaking(from: acc) {
                    practice = parsed
                } else {
                    errorMessage = "Không tạo được nội dung, thử lại"
                }
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isGenerating = false
        }
    }
}

/// Generates a speaking practice and renders it with TTS playback (whole passage + per sentence).
struct SpeakingView: View {
    @Bindable var vm: SpeakingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    vm.generate()
                } label: {
                    Label(vm.practice == nil ? "Tạo bài luyện nói" : "Tạo bài luyện nói mới",
                          systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.green)
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
                    SpeakingContentView(practice: practice)
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    Text("Nhấn nút để tạo một bài luyện nói kèm phiên âm và phát âm mẫu.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

/// Renders the title/topic, a whole-passage TTS button and each sentence card.
private struct SpeakingContentView: View {
    let practice: SpeakingPractice

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
                .buttonStyle(.bordered)
                .tint(Brand.green)
            }

            ForEach(Array(practice.sentences.enumerated()), id: \.element.id) { index, sentence in
                SpeakingSentenceCard(sentence: sentence, number: index + 1)
            }
        }
    }

    private func play(_ text: String) {
        Task { @MainActor in
            try? await TTSService().speak(text)
        }
    }
}

/// A single sentence: text + speaker button, IPA, per-word IPA chips and connected-speech hints.
private struct SpeakingSentenceCard: View {
    let sentence: SpeakingSentence
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.subheadline).bold()
                    .foregroundStyle(.secondary)
                Text(sentence.text ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SpeakerButton(text: sentence.text ?? "")
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
}

/// Wraps the per-word IPA chips onto multiple lines.
private struct FlowChips: View {
    let words: [SpeakingWord]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(words) { word in
                    WordIPAChip(word: word.word ?? "", ipa: word.ipa)
                }
            }
        }
    }
}
