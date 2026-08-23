import Observation
import SwiftUI

/// Landing screen for the Study (spaced-repetition) tab. Loads `stats()` + `due()` on appear,
/// surfaces how many cards are due and launches a full-screen review session.
struct StudyRootView: View {
    @State private var model = StudyModel()
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    heroCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    startButton
                }

                Section {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Xem thống kê", systemImage: "chart.bar.xaxis")
                    }
                }

                if let errorMessage = model.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Học tập")
            .refreshable { await model.load() }
            .task { await model.load() }
            .fullScreenCover(isPresented: $showSession, onDismiss: {
                Task { await model.load() }
            }) {
                ReviewSessionView(items: model.due?.cards ?? [])
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            if model.isLoading && model.due == nil {
                ProgressView()
                    .padding(.vertical, 8)
            } else {
                Text("\(dueCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(dueCount == 0 ? "Không có thẻ nào cần ôn" : "\(dueCount) thẻ cần ôn")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if dueCount == 0 {
                    Text("Tuyệt vời! Quay lại sau nhé.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder private var startButton: some View {
        Button {
            showSession = true
        } label: {
            HStack {
                if model.isLoading && model.due != nil {
                    ProgressView().padding(.trailing, 4)
                }
                Label("Bắt đầu ôn tập", systemImage: "play.fill")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(dueCount == 0 || model.isLoading)
    }

    private var dueCount: Int {
        model.due?.count ?? model.stats?.dueNow ?? 0
    }
}

/// View-model backing the Study landing screen. Loads server state via `StudyService`.
@Observable
final class StudyModel {
    var stats: StudyStats?
    var due: DueResponse?
    var isLoading = false
    var errorMessage: String?

    private let service = StudyService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let statsCall = service.stats()
            async let dueCall = service.due()
            let (loadedStats, loadedDue) = try await (statsCall, dueCall)
            stats = loadedStats
            due = loadedDue
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }
}
