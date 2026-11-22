import SwiftUI
import Observation

/// Generates and holds a batch of multiple-choice vocabulary drills with live score tracking.
@MainActor
@Observable
final class DrillsViewModel {
    var language: CardLanguage = .english
    var drills: [Drill] = []
    var resultsById: [UUID: Bool] = [:]
    var selectedChoicesById: [UUID: String] = [:]
    var isGenerating = false
    var errorMessage: String?
    var hasGenerated = false
    var currentIndex = 0

    private let service = AssistantService()
    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var requestGeneration = 0

    var correctCount: Int {
        resultsById.values.filter { $0 }.count
    }

    var answeredCount: Int {
        resultsById.count
    }

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        cancelGeneration()
        language = newLanguage
        drills = []
        resultsById = [:]
        selectedChoicesById = [:]
        errorMessage = nil
        hasGenerated = false
        currentIndex = 0
    }

    func cancelGeneration() {
        requestGeneration &+= 1
        generateTask?.cancel()
        generateTask = nil
        isGenerating = false
    }

    func recordAnswer(for drillId: UUID, isCorrect: Bool) {
        if resultsById[drillId] == nil {
            resultsById[drillId] = isCorrect
        }
    }

    func generate(count: Int = 5) {
        guard !isGenerating else { return }
        requestGeneration &+= 1
        let expectedGen = requestGeneration
        isGenerating = true
        errorMessage = nil
        drills = []
        resultsById = [:]
        selectedChoicesById = [:]
        currentIndex = 0
        let lang = language

        generateTask?.cancel()
        generateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var acc = ""
            do {
                for try await chunk in service.drills(count: count, language: lang) {
                    if Task.isCancelled || self.requestGeneration != expectedGen { return }
                    acc += chunk
                }
                guard !Task.isCancelled, self.requestGeneration == expectedGen else { return }
                drills = PracticeParsing.drills(from: acc)
                if drills.isEmpty {
                    errorMessage = "Không tạo được nội dung, thử lại"
                    Haptics.notify(.error)
                } else {
                    Haptics.notify(.success)
                }
                hasGenerated = true
            } catch is CancellationError {
                return
            } catch {
                guard self.requestGeneration == expectedGen else { return }
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
                hasGenerated = true
            }
            if self.requestGeneration == expectedGen {
                isGenerating = false
                generateTask = nil
            }
        }
    }

    func goPrevious() {
        if currentIndex > 0 { currentIndex -= 1 }
    }

    func goNext() {
        if currentIndex < drills.count - 1 { currentIndex += 1 }
    }
}

func drillDifficultyColor(_ difficulty: String?) -> Color {
    switch difficulty?.lowercased() {
    case "easy", "dễ", "beginner": return Brand.semanticSuccess
    case "medium", "trung bình", "intermediate": return .orange
    case "hard", "khó", "advanced": return .red
    default: return .secondary
    }
}

/// Generates a batch of drills with step dots, score indicator, and Previous/Next paging.
struct DrillsView: View {
    @Bindable var vm: DrillsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button {
                    Haptics.impact(.light)
                    vm.generate()
                } label: {
                    Label(vm.drills.isEmpty ? "Tạo 5 câu hỏi" : "Tạo lại 5 câu hỏi",
                          systemImage: "wand.and.stars")
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

                if !vm.drills.isEmpty {
                    progressBarRow
                    let index = min(vm.currentIndex, vm.drills.count - 1)
                    let drill = vm.drills[index]
                    DrillCardView(
                        drill: drill,
                        number: index + 1,
                        language: vm.language,
                        selectedChoice: Binding(
                            get: { vm.selectedChoicesById[drill.id] },
                            set: { vm.selectedChoicesById[drill.id] = $0 }
                        ),
                        onAnswered: { isCorrect in
                            vm.recordAnswer(for: drill.id, isCorrect: isCorrect)
                        }
                    )
                    .id(drill.id)
                    pager(index: index)
                }

                if !vm.isGenerating && vm.drills.isEmpty && vm.errorMessage == nil && !vm.hasGenerated {
                    VStack(spacing: 12) {
                        VocaIconBadge(systemImage: "checklist", size: 54, iconSize: 24)
                        Text(vm.language == .chinese
                             ? "Nhấn nút để tạo 5 câu trắc nghiệm Hán ngữ luyện tập."
                             : "Nhấn nút để tạo 5 câu trắc nghiệm luyện tập.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var progressBarRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(vm.drills.enumerated()), id: \.element.id) { idx, drill in
                let result = vm.resultsById[drill.id]
                let isCurrent = idx == vm.currentIndex

                Button {
                    Haptics.selection()
                    vm.currentIndex = idx
                } label: {
                    Text("\(idx + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(stepForeground(isCurrent: isCurrent, result: result))
                        .background(stepBackground(isCurrent: isCurrent, result: result), in: Circle())
                        .overlay(
                            Circle().strokeBorder(isCurrent ? Brand.green : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Câu \(idx + 1)\(result == true ? ", đúng" : (result == false ? ", sai" : ", chưa làm"))")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }

            Spacer()

            VocaPillBadge(
                text: "\(vm.correctCount)/\(vm.drills.count) đúng",
                icon: "checkmark.circle.fill",
                tint: vm.answeredCount > 0 ? Brand.green : .secondary
            )
        }
    }

    private func stepForeground(isCurrent: Bool, result: Bool?) -> Color {
        if result != nil { return .white }
        return isCurrent ? Brand.green : .secondary
    }

    private func stepBackground(isCurrent: Bool, result: Bool?) -> Color {
        if let result { return result ? Brand.semanticSuccess : .red }
        return isCurrent ? Brand.greenSoft : Color(.tertiarySystemFill)
    }

    private func pager(index: Int) -> some View {
        HStack {
            Button {
                Haptics.selection()
                vm.goPrevious()
            } label: {
                Label("Trước", systemImage: "chevron.left")
            }
            .disabled(index == 0)

            Spacer()

            Text("\(index + 1)/\(vm.drills.count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Haptics.selection()
                vm.goNext()
            } label: {
                Label("Sau", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .disabled(index >= vm.drills.count - 1)
        }
        .buttonStyle(.bordered)
        .tint(Brand.green)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

private struct DrillCardView: View {
    let drill: Drill
    let number: Int
    let language: CardLanguage
    @Binding var selectedChoice: String?
    let onAnswered: (Bool) -> Void

    private var questionText: String {
        drill.scenario ?? drill.instruction ?? drill.title ?? ""
    }

    private var effectiveLanguage: CardLanguage {
        questionText.hasChineseCharacters ? .chinese : language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let kind = drill.kind, !kind.isEmpty {
                    Badge(text: kind)
                }
                Spacer()
                if let difficulty = drill.difficulty, !difficulty.isEmpty {
                    Badge(text: difficulty, color: drillDifficultyColor(difficulty), soft: true)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Câu \(number)").font(.subheadline).bold()
                    if let skill = drill.testedSkill, !skill.isEmpty {
                        Text(skill).chip()
                    }
                    if let word = drill.targetWord, !word.isEmpty {
                        Text(word).chip()
                    }
                }
            }

            if let title = drill.title, !title.isEmpty {
                Text(title).font(.headline)
            }
            if let instruction = drill.instruction, !instruction.isEmpty {
                Text(instruction).font(.subheadline).foregroundStyle(.secondary)
            }
            if let scenario = drill.scenario, !scenario.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(scenario)
                        .font(effectiveLanguage == .chinese ? VocaTypography.hanziFont(size: 19, weight: .medium, isCalligraphic: ThemeStore.shared.hanziCalligraphic) : .body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PronounceButton(text: questionText, language: effectiveLanguage, tintedCapsule: true)
                }
            } else if !questionText.isEmpty {
                HStack {
                    Spacer()
                    PronounceButton(text: questionText, language: effectiveLanguage, tintedCapsule: true)
                }
            }

            PracticeChoicesView(
                choices: drill.choices,
                answer: drill.answer,
                explanation: drill.explanation,
                whyWrong: drill.whyWrong,
                speakChoices: true,
                language: effectiveLanguage,
                externalSelection: $selectedChoice,
                onAnswered: onAnswered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
