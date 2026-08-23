import SwiftUI
import Observation

/// Generates and holds a batch of multiple-choice TOEIC drills.
@MainActor
@Observable
final class DrillsViewModel {
    var drills: [Drill] = []
    var isGenerating = false
    var errorMessage: String?
    var hasGenerated = false
    /// Index of the drill currently shown (one-at-a-time paging).
    var currentIndex = 0

    private let service = AssistantService()

    func generate(count: Int = 5) {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        drills = []
        currentIndex = 0

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.drills(count: count) {
                    acc += chunk
                }
                drills = PracticeParsing.drills(from: acc)
                if drills.isEmpty {
                    errorMessage = "Không tạo được nội dung, thử lại"
                }
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            hasGenerated = true
            isGenerating = false
        }
    }

    func goPrevious() {
        if currentIndex > 0 { currentIndex -= 1 }
    }

    func goNext() {
        if currentIndex < drills.count - 1 { currentIndex += 1 }
    }
}

/// Color for a drill difficulty label (easy → green, medium → orange, hard → red).
func drillDifficultyColor(_ difficulty: String?) -> Color {
    switch difficulty?.lowercased() {
    case "easy", "dễ", "beginner": return Brand.green
    case "medium", "trung bình", "intermediate": return .orange
    case "hard", "khó", "advanced": return .red
    default: return .secondary
    }
}

/// Generates a batch of drills and shows them one at a time with Previous/Next paging.
struct DrillsView: View {
    @Bindable var vm: DrillsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button {
                    vm.generate()
                } label: {
                    Label(vm.drills.isEmpty ? "Tạo 5 câu hỏi" : "Tạo lại 5 câu hỏi",
                          systemImage: "wand.and.stars")
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

                if !vm.drills.isEmpty {
                    let index = min(vm.currentIndex, vm.drills.count - 1)
                    DrillCardView(drill: vm.drills[index], number: index + 1)
                        .id(vm.drills[index].id)
                    pager(index: index)
                }

                if !vm.isGenerating && vm.drills.isEmpty && vm.errorMessage == nil && !vm.hasGenerated {
                    Text("Nhấn nút để tạo 5 câu trắc nghiệm luyện tập.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    /// Previous / Next controls with an "i/N" counter.
    private func pager(index: Int) -> some View {
        HStack {
            Button {
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

/// Puts the icon after the title (for a "Next >" button).
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

/// A single drill: kind/difficulty badges, question (with TTS), tappable choices with per-choice TTS,
/// revealed explanation and whyWrong.
private struct DrillCardView: View {
    let drill: Drill
    let number: Int

    private var questionText: String {
        drill.scenario ?? drill.instruction ?? drill.title ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let kind = drill.kind, !kind.isEmpty {
                    Badge(text: kind, color: Brand.green)
                }
                Spacer()
                if let difficulty = drill.difficulty, !difficulty.isEmpty {
                    Badge(text: difficulty, color: drillDifficultyColor(difficulty), soft: true)
                }
            }

            HStack(spacing: 6) {
                Text("Câu \(number)").font(.subheadline).bold()
                if let skill = drill.testedSkill, !skill.isEmpty {
                    Text(skill).chip()
                }
                if let word = drill.targetWord, !word.isEmpty {
                    Text(word).chip()
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PronounceButton(text: questionText)
                }
            } else if !questionText.isEmpty {
                HStack {
                    Spacer()
                    PronounceButton(text: questionText)
                }
            }

            PracticeChoicesView(
                choices: drill.choices,
                answer: drill.answer,
                explanation: drill.explanation,
                whyWrong: drill.whyWrong,
                speakChoices: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
