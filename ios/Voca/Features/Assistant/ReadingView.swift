import SwiftUI
import Observation

/// Generates and holds a reading-comprehension context (Part 6 / Part 7).
@MainActor
@Observable
final class ReadingViewModel {
    var format: String = "part6"
    var context: ReadingContext?
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()

    func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        context = nil
        let format = self.format

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.reading(format: format) {
                    acc += chunk
                }
                if let parsed = PracticeParsing.reading(from: acc) {
                    context = parsed
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

/// Picks a format, generates a passage, and renders it with interactive questions.
struct ReadingView: View {
    @Bindable var vm: ReadingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Định dạng", selection: $vm.format) {
                    Text("Part 6").tag("part6")
                    Text("Part 7").tag("part7")
                }
                .pickerStyle(.segmented)
                .disabled(vm.isGenerating)

                Button {
                    vm.generate()
                } label: {
                    Label("Tạo bài đọc", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isGenerating)

                if vm.isGenerating {
                    ProgressView("Đang tạo…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                if let context = vm.context {
                    ReadingContextView(context: context)
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    Text("Chọn định dạng rồi nhấn nút để tạo một bài đọc luyện tập.")
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

/// Renders the passage / documents, target-word chips and each question.
private struct ReadingContextView: View {
    let context: ReadingContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = context.title, !title.isEmpty {
                Text(title).font(.title3).bold()
            }

            if let words = context.targetWords, !words.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            Text(word).chip()
                        }
                    }
                }
            }

            if let passage = context.passage, !passage.isEmpty {
                passageBlock(passage)
            }

            if let documents = context.documents {
                ForEach(documents) { document in
                    documentBlock(document)
                }
            }

            ForEach(Array(context.questions.enumerated()), id: \.element.id) { index, question in
                ReadingQuestionCard(question: question, number: index + 1)
            }
        }
    }

    private func passageBlock(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .practiceCard()
    }

    private func documentBlock(_ document: ReadingDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = document.title, !title.isEmpty {
                Text(title).font(.headline)
            }
            if let type = document.documentType, !type.isEmpty {
                Text(type).chip()
            }
            if let lines = document.passage {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
        }
        .practiceCard()
    }
}

/// A single reading question with a blank label, prompt and interactive choices.
private struct ReadingQuestionCard: View {
    let question: ReadingQuestion
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Câu \(number)").font(.subheadline).bold()
                if let blank = question.blank {
                    Text("Chỗ trống [\(blank)]").chip()
                }
            }
            if let prompt = question.prompt, !prompt.isEmpty {
                Text(prompt)
            }
            PracticeChoicesView(
                choices: question.choices,
                answer: question.answer,
                explanation: question.explanation)
        }
        .practiceCard()
    }
}
