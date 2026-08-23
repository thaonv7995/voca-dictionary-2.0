import SwiftUI
import Observation

/// Generates and holds a business-article practice set (passage + questions + vocabulary).
@MainActor
@Observable
final class ArticleViewModel {
    var article: ArticlePractice?
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()

    func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        article = nil

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.article() {
                    acc += chunk
                }
                if let parsed = PracticeParsing.article(from: acc) {
                    article = parsed
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

/// Generates an article and renders its passage, interactive questions and vocabulary notes.
struct ArticleView: View {
    @Bindable var vm: ArticleViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    vm.generate()
                } label: {
                    Label(vm.article == nil ? "Tạo bài báo" : "Tạo bài báo mới",
                          systemImage: "newspaper")
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

                if let article = vm.article {
                    ArticleContentView(article: article)
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    Text("Nhấn nút để tạo một bài báo luyện đọc kèm câu hỏi và ghi chú từ vựng.")
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

/// Renders the article title, target-word chips, passage card, questions and vocabulary notes.
private struct ArticleContentView: View {
    let article: ArticlePractice

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = article.title, !title.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(title).font(.title3).bold()
                    Spacer(minLength: 8)
                    if let type = article.documentType, !type.isEmpty {
                        Badge(text: type)
                    }
                }
            }

            if let words = article.targetWords, !words.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            Text(word).chip()
                        }
                    }
                }
            }

            if let passage = article.passage, !passage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(passage.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCard()
            }

            if !article.questions.isEmpty {
                Text("Câu hỏi").font(.headline)
                ForEach(Array(article.questions.enumerated()), id: \.element.id) { index, question in
                    ArticleQuestionCard(question: question, number: index + 1)
                }
            }

            if let notes = article.vocabularyNotes, !notes.isEmpty {
                Text("Ghi chú từ vựng").font(.headline)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(notes) { note in
                        VocabularyNoteRow(note: note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCard()
            }
        }
    }
}

/// A single article question with prompt and interactive choices.
private struct ArticleQuestionCard: View {
    let question: ReadingQuestion
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Câu \(number)").font(.subheadline).bold()
            if let prompt = question.prompt, !prompt.isEmpty {
                Text(prompt)
            }
            PracticeChoicesView(
                choices: question.choices,
                answer: question.answer,
                explanation: question.explanation)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

/// One vocabulary note: word • Vietnamese meaning • contextual meaning.
private struct VocabularyNoteRow: View {
    let note: VocabularyNote

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let word = note.word, !word.isEmpty {
                    Text(word).font(.subheadline).bold().foregroundStyle(Brand.green)
                    PronounceButton(text: word, size: 24, font: .subheadline)
                }
            }
            if let vi = note.meaningVi, !vi.isEmpty {
                Text(vi).font(.subheadline)
            }
            if let context = note.contextMeaning, !context.isEmpty {
                Text(context).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
