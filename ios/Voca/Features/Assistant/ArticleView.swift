import SwiftUI
import Observation

@MainActor
@Observable
final class ArticleViewModel {
    var language: CardLanguage = .english
    var article: ArticlePractice?
    var selectedChoicesById: [UUID: String] = [:]
    var isGenerating = false
    var errorMessage: String?

    private let service = AssistantService()
    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var requestGeneration = 0

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        cancelGeneration()
        language = newLanguage
        article = nil
        selectedChoicesById = [:]
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
        requestGeneration &+= 1
        let expectedGen = requestGeneration
        isGenerating = true
        errorMessage = nil
        article = nil
        selectedChoicesById = [:]
        let lang = language

        generateTask?.cancel()
        generateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var acc = ""
            do {
                for try await chunk in service.article(language: lang) {
                    if Task.isCancelled || self.requestGeneration != expectedGen { return }
                    acc += chunk
                }
                guard !Task.isCancelled, self.requestGeneration == expectedGen else { return }
                if let parsed = PracticeParsing.article(from: acc) {
                    article = parsed
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

/// Generates an article and renders its editorial paper passage, questions, and vocabulary notes.
struct ArticleView: View {
    @Bindable var vm: ArticleViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    Haptics.impact(.light)
                    vm.generate()
                } label: {
                    Label(vm.article == nil ? "Tạo bài báo" : "Tạo bài báo mới",
                          systemImage: "newspaper")
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

                if let article = vm.article {
                    ArticleContentView(
                        article: article,
                        language: vm.language,
                        selectedChoicesById: $vm.selectedChoicesById
                    )
                } else if !vm.isGenerating && vm.errorMessage == nil {
                    VStack(spacing: 12) {
                        VocaIconBadge(systemImage: "newspaper", size: 54, iconSize: 24)
                        Text(vm.language == .chinese
                             ? "Nhấn nút để tạo một bài báo Hán ngữ kèm câu hỏi và ghi chú từ vựng."
                             : "Nhấn nút để tạo một bài báo luyện đọc kèm câu hỏi và ghi chú từ vựng.")
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

private struct ArticleContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    let article: ArticlePractice
    let language: CardLanguage
    @Binding var selectedChoicesById: [UUID: String]

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
                VocaFlowLayout(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        Text(word).chip()
                    }
                }
            }

            if let passage = article.passage, !passage.isEmpty {
                let isChinese = passage.joined().hasChineseCharacters || language == .chinese
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VocaPillBadge(text: "Bài báo", icon: "newspaper.fill")
                        Spacer()
                        PronounceButton(
                            text: passage.joined(separator: "\n"),
                            language: isChinese ? .chinese : language,
                            tintedCapsule: true
                        )
                    }
                    ForEach(Array(passage.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(isChinese ? VocaTypography.hanziFont(size: 18, weight: .regular, isCalligraphic: ThemeStore.shared.hanziCalligraphic) : .system(.body, design: .serif))
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

            if !article.questions.isEmpty {
                Text("Câu hỏi").font(.headline)
                ForEach(Array(article.questions.enumerated()), id: \.element.id) { index, question in
                    ArticleQuestionCard(
                        question: question,
                        number: index + 1,
                        language: language,
                        selectedChoice: Binding(
                            get: { selectedChoicesById[question.id] },
                            set: { selectedChoicesById[question.id] = $0 }
                        )
                    )
                }
            }

            if let notes = article.vocabularyNotes, !notes.isEmpty {
                Text("Ghi chú từ vựng").font(.headline)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                        VocabularyNoteRow(note: note, language: language)
                        if idx < notes.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCard()
            }
        }
    }
}

private struct ArticleQuestionCard: View {
    let question: ReadingQuestion
    let number: Int
    let language: CardLanguage
    @Binding var selectedChoice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Câu \(number)").font(.subheadline).bold()
            if let prompt = question.prompt, !prompt.isEmpty {
                Text(prompt)
            }
            PracticeChoicesView(
                choices: question.choices,
                answer: question.answer,
                explanation: question.explanation,
                speakChoices: question.choices.contains(where: \.hasChineseCharacters),
                language: language,
                externalSelection: $selectedChoice)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

private struct VocabularyNoteRow: View {
    let note: VocabularyNote
    let language: CardLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let word = note.word, !word.isEmpty {
                    Text(word).font(.subheadline).bold().foregroundStyle(Brand.green)
                    PronounceButton(
                        text: word,
                        language: word.hasChineseCharacters ? .chinese : language,
                        size: 26,
                        font: .subheadline,
                        tintedCapsule: true
                    )
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
