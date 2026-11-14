import SwiftUI
import Observation

@MainActor
@Observable
final class ReadingViewModel {
    var language: CardLanguage = .english
    var format: String = "part6"
    var context: ReadingContext?
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        language = newLanguage
        if !isGenerating {
            context = nil
            errorMessage = nil
        }
    }

    func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        context = nil
        let format = self.format
        let lang = self.language

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.reading(format: format, language: lang) {
                    acc += chunk
                }
                if let parsed = PracticeParsing.reading(from: acc) {
                    context = parsed
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

/// Picks a format, generates a passage with warm reading paper card styling, and renders questions.
struct ReadingView: View {
    @Bindable var vm: ReadingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Định dạng", selection: $vm.format) {
                    Text(vm.language == .chinese ? "Điền từ" : "Part 6").tag("part6")
                    Text(vm.language == .chinese ? "Đọc hiểu" : "Part 7").tag("part7")
                }
                .pickerStyle(.segmented)
                .disabled(vm.isGenerating)

                Button {
                    Haptics.impact(.light)
                    vm.generate()
                } label: {
                    Label("Tạo bài đọc", systemImage: "doc.text")
                }
                .buttonStyle(BrandCTAButtonStyle())
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
                    ReadingContextView(context: context, language: vm.language)
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    VStack(spacing: 12) {
                        VocaIconBadge(systemImage: "doc.text", size: 54, iconSize: 24)
                        Text(vm.language == .chinese
                             ? "Chọn định dạng rồi nhấn nút để tạo bài đọc Hán ngữ luyện tập."
                             : "Chọn định dạng rồi nhấn nút để tạo một bài đọc luyện tập.")
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

private struct ReadingContextView: View {
    @Environment(\.colorScheme) private var colorScheme
    let context: ReadingContext
    let language: CardLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = context.title, !title.isEmpty {
                Text(title).font(.title3).bold()
            }

            if let words = context.targetWords, !words.isEmpty {
                VocaFlowLayout(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        Text(word).chip()
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
                ReadingQuestionCard(question: question, number: index + 1, language: language)
            }
        }
    }

    private func passageBlock(_ lines: [String]) -> some View {
        let isChinese = lines.joined().hasChineseCharacters || language == .chinese
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VocaPillBadge(text: "Đoạn đọc", icon: "book.pages.fill")
                Spacer()
                PronounceButton(
                    text: lines.joined(separator: "\n"),
                    language: isChinese ? .chinese : language,
                    tintedCapsule: true
                )
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(isChinese ? VocaTypography.hanziFont(size: 18, weight: .regular) : .system(.body, design: .serif))
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Brand.readingPaper(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Brand.readingPaperBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func documentBlock(_ document: ReadingDocument) -> some View {
        let joined = document.passage?.joined() ?? ""
        let isChinese = joined.hasChineseCharacters || language == .chinese
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                if let title = document.title, !title.isEmpty {
                    Text(title).font(.headline)
                }
                Spacer()
                if let lines = document.passage, !lines.isEmpty {
                    PronounceButton(
                        text: lines.joined(separator: "\n"),
                        language: isChinese ? .chinese : language,
                        tintedCapsule: true
                    )
                }
            }
            if let type = document.documentType, !type.isEmpty {
                Text(type).chip()
            }
            if let lines = document.passage {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(isChinese ? VocaTypography.hanziFont(size: 18, weight: .regular) : .system(.body, design: .serif))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Brand.readingPaper(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Brand.readingPaperBorder(for: colorScheme), lineWidth: 1)
        )
    }
}

private struct ReadingQuestionCard: View {
    let question: ReadingQuestion
    let number: Int
    let language: CardLanguage

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
                explanation: question.explanation,
                speakChoices: question.choices.contains(where: \.hasChineseCharacters),
                language: language)
        }
        .practiceCard()
    }
}
