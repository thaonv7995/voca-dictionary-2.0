import SwiftUI

struct MacTodaySnapshot: Equatable, Sendable {
    var dueCount: Int
    var completedToday: Int
    var dailyGoal: Int
    var streakDays: Int
    var difficultWordCount: Int
    var recentlyAddedCount: Int

    static let preview = MacTodaySnapshot(
        dueCount: 18,
        completedToday: 7,
        dailyGoal: 20,
        streakDays: 6,
        difficultWordCount: 8,
        recentlyAddedCount: 12
    )

    var completedGoalCount: Int {
        min(completedToday, dailyGoal)
    }

    var remainingGoalCount: Int {
        max(dailyGoal - completedToday, 0)
    }

    var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(completedToday) / Double(dailyGoal), 1)
    }
}

struct MacTodayView: View {
    @Environment(MacTodayStore.self) private var today
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech
    @Environment(MacAppRouter.self) private var router

    let startReview: () -> Void
    let openVocabulary: () -> Void
    let startPractice: () -> Void

    private var snapshot: MacTodaySnapshot {
        today.snapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if today.isLoading {
                    ProgressView("Đang cập nhật tiến độ học…")
                        .controlSize(.small)
                } else if let errorMessage = today.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(VocaDesign.accentAmber)

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Spacer()

                        Button("Thử lại") {
                            Task {
                                await today.retry(
                                    dailyGoal: preferences.dailyGoal
                                )
                            }
                        }
                        .buttonStyle(VocaSecondaryButtonStyle())
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                primaryAction
                summaryGrid
                learningSection
                if !vocabulary.items.isEmpty {
                    spotlightVocabularySection
                }
            }
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .navigationTitle("Hôm nay")
        .background(VocaDesign.subtleWindowBackground)
        .task {
            async let todayLoad: Void = today.load(
                dailyGoal: preferences.dailyGoal
            )
            async let vocabLoad: Void = vocabulary.load()
            _ = await (todayLoad, vocabLoad)
        }
        .onChange(of: preferences.dailyGoal) { _, dailyGoal in
            today.updateDailyGoal(dailyGoal)

            Task {
                await today.load(dailyGoal: dailyGoal)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                headerTitleBlock
                Spacer(minLength: 16)
                headerActionsBlock
            }

            VStack(alignment: .leading, spacing: 12) {
                headerTitleBlock
                headerActionsBlock
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Hôm nay")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                if snapshot.streakDays > 0 {
                    VocaPillBadge(
                        text: "\(snapshot.streakDays) ngày liên tục",
                        icon: "flame.fill",
                        tint: VocaDesign.accentAmber
                    )
                }
            }

            Text("Duy trì thói quen học mỗi ngày với một phiên tập trung.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var headerActionsBlock: some View {
        HStack(spacing: 10) {
            Button {
                router.open(.quickLookup(query: nil))
            } label: {
                Label("Tra nhanh", systemImage: "magnifyingglass")
            }
            .buttonStyle(VocaSecondaryButtonStyle())

            Button {
                router.requestAddWord()
            } label: {
                Label("Thêm từ", systemImage: "plus")
            }
            .buttonStyle(VocaPrimaryButtonStyle())
        }
    }

    private var goalRingView: some View {
        ZStack {
            Circle()
                .stroke(VocaDesign.brandGreen.opacity(0.16), lineWidth: 8)
            Circle()
                .trim(from: 0, to: snapshot.goalProgress)
                .stroke(
                    VocaDesign.brandGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: snapshot.goalProgress)

            VStack(spacing: 1) {
                Text("\(Int(snapshot.goalProgress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Mục tiêu")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 78, height: 78)
    }

    private var primaryActionTextBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VocaPillBadge(
                    text: snapshot.dueCount > 0 ? "Sẵn sàng ôn tập" : "Đã hoàn thành",
                    icon: snapshot.dueCount > 0 ? "sparkles" : "checkmark.seal.fill",
                    tint: snapshot.dueCount > 0 ? VocaDesign.brandGreen : VocaDesign.accentSky
                )

                Text(goalProgressDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(
                snapshot.dueCount > 0
                    ? "\(snapshot.dueCount) thẻ cần ôn tập ngay"
                    : "Bạn đã hoàn thành lịch ôn hôm nay"
            )
            .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(primaryActionMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var primaryActionButton: some View {
        Button(action: primaryActionHandler) {
            HStack(spacing: 8) {
                Image(systemName: primaryActionIcon)
                Text(primaryActionTitle)
            }
        }
        .buttonStyle(VocaPrimaryButtonStyle())
        .keyboardShortcut(.return, modifiers: [.command])
    }

    private var primaryAction: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                goalRingView
                primaryActionTextBlock
                Spacer(minLength: 16)
                primaryActionButton
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    goalRingView
                    primaryActionTextBlock
                }
                primaryActionButton
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VocaDesign.heroBannerGradient)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                )
                .shadow(color: VocaDesign.brandGreen.opacity(0.08), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(VocaDesign.brandGreen.opacity(0.24), lineWidth: 1)
        )
    }

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 200, maximum: 440), spacing: 16)
            ],
            spacing: 16
        ) {
            summaryCard(
                title: "Mục tiêu ngày",
                value: "\(snapshot.completedGoalCount)/\(snapshot.dailyGoal)",
                detail: snapshot.remainingGoalCount == 0
                    ? "Đã hoàn thành mục tiêu 🎉"
                    : "Còn \(snapshot.remainingGoalCount) hoạt động nữa",
                systemImage: "target",
                tint: VocaDesign.brandGreen
            )

            summaryCard(
                title: "Chuỗi học tập",
                value: "\(snapshot.streakDays)",
                detail: "\(snapshot.streakDays) ngày liên tiếp",
                systemImage: "flame.fill",
                tint: VocaDesign.accentAmber
            )

            summaryCard(
                title: "Thẻ đến hạn",
                value: "\(snapshot.dueCount)",
                detail: "\(snapshot.dueCount) thẻ cần ôn tập",
                systemImage: "clock.badge.checkmark.fill",
                tint: VocaDesign.accentIndigo
            )
        }
    }

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tiếp tục học")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 640), spacing: 16)
                ],
                spacing: 16
            ) {
                actionCard(
                    title: "Từ vựng cần nhớ lại",
                    detail: "\(snapshot.difficultWordCount) từ vựng cần chú ý ôn thêm",
                    systemImage: "bolt.heart.fill",
                    tint: VocaDesign.accentRose,
                    actionTitle: "Luyện tập ngay",
                    action: startPractice
                )

                actionCard(
                    title: "Mới thêm gần đây",
                    detail: "\(snapshot.recentlyAddedCount) từ vựng trong bộ sưu tập",
                    systemImage: "books.vertical.fill",
                    tint: VocaDesign.accentSky,
                    actionTitle: "Xem danh sách",
                    action: openVocabulary
                )
            }
        }
    }

    private var spotlightVocabularySection: some View {
        let spotlightItems = Array(
            vocabulary.items
                .sorted { left, right in
                    if left.isDue != right.isDue {
                        return left.isDue
                    }
                    if left.isFavorite != right.isFavorite {
                        return left.isFavorite
                    }
                    return left.term < right.term
                }
                .prefix(6)
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Từ vựng ưu tiên & Gần đây")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    openVocabulary()
                } label: {
                    HStack(spacing: 4) {
                        Text("Xem tất cả (\(vocabulary.items.count))")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VocaDesign.brandGreen)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(spotlightItems) { item in
                    Button {
                        router.open(.vocabularyWord(id: item.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.term)
                                    .font(
                                        item.language == .chinese
                                            ? VocaDesign.hanziFont(size: 20, weight: .bold)
                                            : .system(size: 16, weight: .bold, design: .rounded)
                                    )
                                    .foregroundStyle(.primary)

                                if let pronunciation = item.pronunciation {
                                    Text(pronunciation)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(VocaDesign.brandGreen)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button {
                                    speech.toggle(item.term, language: item.language)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(VocaDesign.brandGreen)
                                        .frame(width: 24, height: 24)
                                        .background(VocaDesign.brandGreen.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            Text(item.displayMeaningVi)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VocaSurfaceCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VocaIconBadge(
                        systemImage: systemImage,
                        tint: tint,
                        size: 38,
                        iconSize: 17
                    )
                    Spacer()
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func actionCard(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VocaSurfaceCard(padding: 20, cornerRadius: 16) {
            HStack(spacing: 16) {
                VocaIconBadge(
                    systemImage: systemImage,
                    tint: tint,
                    size: 46,
                    iconSize: 20
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(actionTitle, action: action)
                    .buttonStyle(VocaSecondaryButtonStyle(tint: tint))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryActionTitle: String {
        if snapshot.dueCount > 0 {
            return "Bắt đầu ôn tập"
        }

        return "Luyện tập"
    }

    private var primaryActionIcon: String {
        snapshot.dueCount > 0 ? "play.fill" : "sparkles"
    }

    private var primaryActionMessage: String {
        if snapshot.dueCount > 0 {
            return "Ôn tập các thẻ đến hạn trước khi bắt đầu hoạt động mới."
        }

        return "Hiện chưa có thẻ nào đến hạn. Luyện tập thêm từ mới để ghi nhớ sâu hơn."
    }

    private var goalProgressDescription: String {
        if snapshot.remainingGoalCount == 0 {
            return "Đã đạt mục tiêu ngày"
        }

        return "Đã hoàn thành \(snapshot.completedGoalCount)/\(snapshot.dailyGoal) hoạt động"
    }

    private func primaryActionHandler() {
        if snapshot.dueCount > 0 {
            startReview()
        } else {
            startPractice()
        }
    }
}

struct MacTodayView_Previews: PreviewProvider {
    static var previews: some View {
        MacTodayView(
            startReview: {},
            openVocabulary: {},
            startPractice: {}
        )
        .environment(
            MacTodayStore(
                repository: PreviewMacTodayRepository()
            )
        )
        .environment(MacPreferencesStore())
        .frame(width: 1000, height: 760)
    }
}
