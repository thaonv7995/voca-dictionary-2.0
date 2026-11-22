import Observation
import SwiftUI

/// Redesigned "Ôn tập" (Study) Hub — FSRS hero + daily goal ring, smart quick decks,
/// level & topic drills, and compact session preferences sheet.
struct StudyRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var model = StudyModel()
    @State private var showReviewSession = false
    @State private var activeBrowseSession: BrowseWrapper?
    @State private var showPreferences = false
    @State private var showAllTopics = false
    @State private var dayRefreshToken = UUID()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var dueItems: [DueItem] {
        (model.due?.cards ?? []).filter { $0.card.cardLanguage == language }
    }

    private var dueCount: Int { dueItems.count }

    private var languageCards: [Card] {
        model.cards(for: language)
    }

    private var learningCards: [Card] {
        model.learningCards(for: language)
    }

    private var favoriteCards: [Card] {
        languageCards.filter { learner.isFavorite($0.slug) }
    }

    private var recentCards: [Card] {
        model.recentCards(for: language)
    }

    private var topicGroups: [StudyTopicGroup] {
        model.topicGroups(for: language)
    }

    private var activeOptionTags: [String] {
        var tags: [String] = []
        if theme.reverseFlashcardMode { tags.append("Đảo mặt") }
        if theme.autoSpeakFlashcard { tags.append("Tự phát âm") }
        if theme.autoFlipFlashcard {
            tags.append("Tự lật · \(ThemeStore.formatDelay(theme.autoFlipDelaySeconds, short: true))")
        }
        if theme.autoAdvanceFlashcard {
            tags.append("Tự lướt · \(ThemeStore.formatDelay(theme.autoAdvanceDelaySeconds, short: true))")
        }
        return tags
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    hubContent
                }
            }
            .navigationTitle("Ôn tập")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Thống kê chi tiết")

                    Button {
                        Haptics.selection()
                        showPreferences = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                            if !activeOptionTags.isEmpty {
                                Circle()
                                    .fill(Brand.green)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 3, y: -2)
                            }
                        }
                    }
                    .accessibilityLabel("Tùy chọn phiên học")
                }
            }
            .refreshable { await model.load() }
            .onAppear {
                model.syncFromCache()
                if model.shouldRefreshOnAppear {
                    Task { await model.load() }
                }
            }
            .task { await model.load() }
            .task(id: "cache-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                    model.syncFromCache()
                }
            }
            .task(id: "study-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.studyDidChangeNotification) {
                    model.syncFromCache()
                }
            }
            .task(id: "day-change") {
                for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                    dayRefreshToken = UUID()
                    await model.load()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    dayRefreshToken = UUID()
                    model.syncFromCache()
                    if model.shouldRefreshOnAppear {
                        Task { await model.load() }
                    }
                }
            }
            .onChange(of: languageRaw) { _, _ in
                showAllTopics = false
            }
            .sheet(isPresented: $showPreferences) {
                StudyPreferencesSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showReviewSession, onDismiss: {
                Task { await model.load() }
            }) {
                ReviewSessionView(items: dueItems)
            }
            .fullScreenCover(item: $activeBrowseSession) { wrapper in
                ReviewSessionView(browseCards: wrapper.cards, title: wrapper.title)
            }
        }
    }

    // MARK: - Responsive Hub Layout

    @ViewBuilder private var hubContent: some View {
        if horizontalSizeClass == .regular {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trung tâm ôn luyện")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(language == .chinese ? "Tiếng Trung · \(languageCards.count) thẻ" : "Tiếng Anh · \(languageCards.count) thẻ")
                            .font(.title3.weight(.bold))
                    }
                    Spacer(minLength: 0)
                    CardLanguagePicker(selection: $languageRaw)
                        .frame(width: 300)
                }

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 20) {
                            fsrsHeroCard
                            quickDecksSection
                        }
                        .frame(minWidth: 340, maxWidth: .infinity)

                        VStack(spacing: 20) {
                            levelsSection
                            if !topicGroups.isEmpty {
                                topicsSection
                            }
                            statsFooterCard
                        }
                        .frame(minWidth: 320, maxWidth: .infinity)
                    }

                    VStack(spacing: 18) {
                        fsrsHeroCard
                        quickDecksSection
                        levelsSection
                        if !topicGroups.isEmpty {
                            topicsSection
                        }
                        statsFooterCard
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 18) {
                CardLanguagePicker(selection: $languageRaw)

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }

                fsrsHeroCard
                quickDecksSection
                levelsSection
                if !topicGroups.isEmpty {
                    topicsSection
                }
                statsFooterCard
            }
            .padding()
        }
    }

    // MARK: - 1. FSRS Hero + Daily Goal Ring

    @ViewBuilder private var fsrsHeroCard: some View {
        let isInitialLoading = model.isLoading && model.due == nil

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                VocaPillBadge(
                    text: "Lịch ôn FSRS",
                    icon: "sparkles",
                    tint: Brand.green
                )

                if learner.streakDays > 0 {
                    VocaPillBadge(
                        text: "\(learner.streakDays) ngày",
                        icon: "flame.fill",
                        tint: .orange
                    )
                }

                Spacer(minLength: 0)

                if model.isLoading && model.due != nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if isInitialLoading {
                        ProgressView()
                            .frame(height: 44, alignment: .leading)
                    } else if dueCount > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(dueCount)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Brand.green)
                                .contentTransition(.numericText())
                            Text("thẻ đến hạn")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Text("Ôn đúng thời điểm quên để ghi nhớ dài lâu.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Hoàn tất hôm nay!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(languageCards.isEmpty
                             ? "Hãy thêm từ mới vào Kho từ để bắt đầu ôn tập."
                             : "Không còn thẻ FSRS đến hạn. Bạn có thể luyện thêm bộ thẻ tự do bên dưới.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Haptics.selection()
                    showPreferences = true
                } label: {
                    DailyGoalRing(
                        reviewed: learner.reviewedTodayCount,
                        goal: learner.dailyGoal
                    )
                }
                .buttonStyle(.plain)
                .id(dayRefreshToken)
            }

            // Compact active options strip + quick button to open preferences sheet
            HStack(spacing: 8) {
                if activeOptionTags.isEmpty {
                    Label("Chế độ mặc định", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(activeOptionTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Brand.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Brand.greenSoft, in: Capsule())
                            }
                        }
                    }
                }

                Spacer(minLength: 4)

                Button {
                    Haptics.selection()
                    showPreferences = true
                } label: {
                    Text("Tùy chỉnh")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Brand.elevatedFill(for: colorScheme), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Primary CTA
            if dueCount > 0 {
                Button {
                    Haptics.impact(.medium)
                    showReviewSession = true
                } label: {
                    Label("Bắt đầu ôn tập (\(dueCount))", systemImage: "play.fill")
                }
                .buttonStyle(BrandCTAButtonStyle())
                .disabled(isInitialLoading)
            } else if !learningCards.isEmpty {
                Button {
                    Haptics.impact(.light)
                    openBrowse(cards: learningCards, title: "Thẻ chưa vững")
                } label: {
                    Label("Luyện \(learningCards.count) thẻ chưa vững", systemImage: "flame.fill")
                }
                .buttonStyle(BrandCTAButtonStyle())
            } else if !languageCards.isEmpty {
                Button {
                    Haptics.impact(.light)
                    openBrowse(cards: languageCards, title: "Tất cả · \(language.label)")
                } label: {
                    Label("Luyện lại bộ thẻ (\(languageCards.count))", systemImage: "sparkles.rectangle.stack.fill")
                }
                .buttonStyle(BrandCTAButtonStyle())
            } else {
                Button {} label: {
                    Label("Chưa có thẻ để ôn", systemImage: "tray")
                }
                .buttonStyle(BrandCTAButtonStyle())
                .disabled(true)
            }
        }
        .brandHeroCard(padding: 18, cornerRadius: 22)
    }

    // MARK: - 2. Quick Smart Decks Grid

    @ViewBuilder private var quickDecksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bộ thẻ luyện nhanh")
                    .font(.headline)
                Spacer()
                Text("Không ảnh hưởng FSRS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                StudyDeckTile(
                    title: "Chưa vững",
                    subtitle: "Mới & đang học",
                    count: learningCards.count,
                    icon: "flame.fill",
                    tint: .orange
                ) {
                    openBrowse(cards: learningCards, title: "Thẻ chưa vững")
                }

                StudyDeckTile(
                    title: "Yêu thích",
                    subtitle: "Đã đánh dấu sao",
                    count: favoriteCards.count,
                    icon: "star.fill",
                    tint: .pink
                ) {
                    openBrowse(cards: favoriteCards, title: "Thẻ yêu thích")
                }

                StudyDeckTile(
                    title: "Mới thêm",
                    subtitle: "20 thẻ gần nhất",
                    count: recentCards.count,
                    icon: "clock.arrow.circlepath",
                    tint: .indigo
                ) {
                    openBrowse(cards: recentCards, title: "Mới thêm gần đây")
                }

                StudyDeckTile(
                    title: "Tất cả thẻ",
                    subtitle: "Toàn bộ \(language.label)",
                    count: languageCards.count,
                    icon: "rectangle.stack.fill",
                    tint: Brand.green
                ) {
                    openBrowse(cards: languageCards, title: "Tất cả · \(language.label)")
                }
            }
        }
    }

    // MARK: - 3. Level Drills

    @ViewBuilder private var levelsSection: some View {
        let total = languageCards.count

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Luyện theo cấp độ")
                    .font(.headline)
                Spacer()
                Text("\(total) thẻ")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                if total > 0 {
                    let segments = CardLevel.allCases.compactMap { level -> (level: CardLevel, count: Int)? in
                        let c = model.cards(for: level, language: language).count
                        return c > 0 ? (level, c) : nil
                    }
                    GeometryReader { geo in
                        let widths = Self.normalizedSegmentWidths(
                            counts: segments.map(\.count),
                            totalWidth: geo.size.width,
                            spacing: 3,
                            minSegmentWidth: 8
                        )
                        HStack(spacing: 3) {
                            ForEach(Array(segments.enumerated()), id: \.element.level) { idx, seg in
                                Capsule()
                                    .fill(Brand.levelColor(seg.level.rawValue))
                                    .frame(width: widths[idx])
                            }
                        }
                    }
                    .frame(height: 8)
                }

                VStack(spacing: 0) {
                    ForEach(Array(CardLevel.allCases.enumerated()), id: \.element.id) { idx, level in
                        let levelCards = model.cards(for: level, language: language)
                        let color = Brand.levelColor(level.rawValue)
                        let pct = total > 0 ? Int((Double(levelCards.count) / Double(total) * 100).rounded()) : 0

                        Button {
                            openBrowse(cards: levelCards, title: "Cấp độ · \(level.label)")
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 10, height: 10)

                                Text(level.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(levelCards.isEmpty ? .secondary : .primary)

                                Spacer()

                                Text("\(levelCards.count)")
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(levelCards.isEmpty ? Color.secondary.opacity(0.6) : color)

                                Text("(\(pct)%)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 38, alignment: .trailing)

                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(levelCards.isEmpty)
                        .opacity(levelCards.isEmpty ? 0.5 : 1)

                        if idx < CardLevel.allCases.count - 1 {
                            Divider().opacity(0.55)
                        }
                    }
                }
            }
            .brandCard(padding: 16, cornerRadius: 18)
        }
    }

    // MARK: - 4. Topic Drills

    @ViewBuilder private var topicsSection: some View {
        let visibleTopics = showAllTopics ? topicGroups : Array(topicGroups.prefix(10))
        let hiddenCount = max(0, topicGroups.count - visibleTopics.count)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Luyện theo chủ đề")
                    .font(.headline)
                Spacer()
                Text("\(topicGroups.count) chủ đề")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                VocaFlowLayout(spacing: 8) {
                    ForEach(visibleTopics) { group in
                        Button {
                            openBrowse(cards: group.cards, title: group.topic)
                        } label: {
                            HStack(spacing: 6) {
                                Text(group.topic)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(group.cards.count)")
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Brand.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Brand.greenSoft, in: Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Brand.elevatedFill(for: colorScheme), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(PressableScaleStyle(scale: 0.96))
                    }
                }

                if topicGroups.count > 10 {
                    Button {
                        withAnimation(.snappy) { showAllTopics.toggle() }
                    } label: {
                        Label(
                            showAllTopics ? "Thu gọn" : "Xem thêm \(hiddenCount) chủ đề",
                            systemImage: showAllTopics ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .brandCard(padding: 16, cornerRadius: 18)
        }
    }

    // MARK: - 5. Stats Footer Link

    @ViewBuilder private var statsFooterCard: some View {
        let mastered = model.cards(for: .mastered, language: language).count
        let total = languageCards.count
        let pct = total > 0 ? Int((Double(mastered) / Double(total) * 100).rounded()) : 0

        NavigationLink {
            StatsView()
        } label: {
            HStack(spacing: 12) {
                VocaIconBadge(systemImage: "chart.bar.xaxis", size: 40, iconSize: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thống kê chi tiết")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Thành thạo \(pct)% (\(mastered)/\(total)) · Hôm nay \(learner.reviewedTodayCount)/\(learner.dailyGoal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .brandCard(padding: 14, cornerRadius: 18)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.985))
    }

    // MARK: - Helpers

    private func openBrowse(cards: [Card], title: String) {
        guard !cards.isEmpty else { return }
        Haptics.impact(.light)
        activeBrowseSession = BrowseWrapper(cards: cards, title: title)
    }

    @ViewBuilder private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("Thử lại") { Task { await model.load() } }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.green)
        }
        .brandCard(padding: 14, cornerRadius: 16)
    }

    private struct BrowseWrapper: Identifiable {
        let id = UUID()
        let cards: [Card]
        let title: String
    }

    private static func normalizedSegmentWidths(
        counts: [Int],
        totalWidth: CGFloat,
        spacing: CGFloat,
        minSegmentWidth: CGFloat
    ) -> [CGFloat] {
        guard !counts.isEmpty else { return [] }
        let usable = max(0, totalWidth - spacing * CGFloat(max(0, counts.count - 1)))
        let sum = CGFloat(counts.reduce(0, +))
        guard sum > 0, usable > 0 else { return Array(repeating: 0, count: counts.count) }
        let effectiveMin = min(minSegmentWidth, usable / CGFloat(counts.count))
        var widths = counts.map { usable * CGFloat($0) / sum }
        var clamped = Set<Int>()
        var deficit: CGFloat = 0
        for i in widths.indices where widths[i] < effectiveMin {
            deficit += effectiveMin - widths[i]
            widths[i] = effectiveMin
            clamped.insert(i)
        }
        if deficit > 0 {
            let flexibleIndices = widths.indices.filter { !clamped.contains($0) }
            let flexTotal = flexibleIndices.reduce(CGFloat(0)) { $0 + max(0, widths[$1] - effectiveMin) }
            if flexTotal > 0 {
                for i in flexibleIndices {
                    let room = max(0, widths[i] - effectiveMin)
                    widths[i] -= deficit * (room / flexTotal)
                }
            }
        }
        return widths
    }
}

// MARK: - Subviews

private struct DailyGoalRing: View {
    let reviewed: Int
    let goal: Int

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(reviewed) / Double(goal))
    }

    private var reached: Bool {
        goal > 0 && reviewed >= goal
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.greenSoft, lineWidth: 7)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    reached ? AnyShapeStyle(Brand.semanticSuccess) : AnyShapeStyle(Brand.gradient),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: fraction)

            VStack(spacing: 0) {
                Text("\(reviewed)/\(goal)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(reached ? Brand.semanticSuccess : .primary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("mục tiêu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: 72, height: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mục tiêu hôm nay \(reviewed) trên \(goal) thẻ")
        .accessibilityHint("Chạm để chỉnh mục tiêu và tùy chọn phiên học")
    }
}

private struct StudyDeckTile: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VocaIconBadge(systemImage: icon, tint: tint, size: 36, iconSize: 16)
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(count > 0 ? tint : .secondary)
                        .contentTransition(.numericText())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard(padding: 14, cornerRadius: 16)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
        .disabled(count == 0)
        .opacity(count == 0 ? 0.52 : 1)
    }
}

private struct StudyPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner

    var body: some View {
        @Bindable var bindableTheme = theme
        @Bindable var bindableLearner = learner

        NavigationStack {
            Form {
                Section("Mục tiêu hằng ngày") {
                    Stepper(value: $bindableLearner.dailyGoal, in: 5...100, step: 5) {
                        HStack {
                            Label("Số thẻ mỗi ngày", systemImage: "target")
                            Spacer()
                            Text("\(learner.dailyGoal) thẻ")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Brand.green)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $bindableTheme.reverseFlashcardMode) {
                        Label("Đảo mặt thẻ (Nghĩa → Từ)", systemImage: "arrow.left.arrow.right")
                    }
                    .tint(Brand.green)

                    Toggle(isOn: $bindableTheme.autoSpeakFlashcard) {
                        Label("Tự động phát âm khi mở thẻ", systemImage: "speaker.wave.2")
                    }
                    .tint(Brand.green)

                    Toggle(isOn: $bindableTheme.autoFlipFlashcard) {
                        Label("Tự động lật thẻ (Auto-flip)", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(Brand.green)

                    if theme.autoFlipFlashcard {
                        Stepper(
                            value: $bindableTheme.autoFlipDelaySeconds,
                            in: ThemeStore.autoFlipDelayRange,
                            step: 0.5
                        ) {
                            HStack {
                                Label("Thời gian chờ lật", systemImage: "timer")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ThemeStore.formatDelay(theme.autoFlipDelaySeconds))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Brand.green)
                            }
                        }
                    }

                    Toggle(isOn: $bindableTheme.autoAdvanceFlashcard) {
                        Label("Tự động lướt thẻ (Thẻ lật tự do)", systemImage: "arrow.right.circle")
                    }
                    .tint(Brand.green)

                    if theme.autoAdvanceFlashcard {
                        Stepper(
                            value: $bindableTheme.autoAdvanceDelaySeconds,
                            in: ThemeStore.autoAdvanceDelayRange,
                            step: 0.5
                        ) {
                            HStack {
                                Label("Thời gian qua thẻ mới", systemImage: "forward.frame")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ThemeStore.formatDelay(theme.autoAdvanceDelaySeconds))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Brand.green)
                            }
                        }
                    }
                } header: {
                    Text("Tùy chọn phiên học")
                } footer: {
                    Text("Tự động lướt thẻ chỉ áp dụng cho Thẻ lật tự do để không ảnh hưởng lịch ôn FSRS.")
                }

                Section("Hiển thị & Cảm giác") {
                    Toggle(isOn: $bindableTheme.hanziCalligraphic) {
                        HStack(spacing: 10) {
                            Text("学")
                                .font(VocaTypography.hanziFont(size: 18, weight: .bold, isCalligraphic: theme.hanziCalligraphic))
                                .foregroundStyle(Brand.green)
                                .frame(width: 26, height: 26)
                                .background(Brand.greenSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text("Chữ Hán nét thanh đậm")
                        }
                    }
                    .tint(Brand.green)

                    Toggle(isOn: $bindableTheme.hapticsEnabled) {
                        Label("Phản hồi rung (Haptics)", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Brand.green)
                }
            }
            .navigationTitle("Tùy chọn ôn tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Indexed Study Model

struct StudyTopicGroup: Identifiable, Hashable {
    let topic: String
    let cards: [Card]
    var id: String { topic }
}

/// View-model backing the Study landing hub with pre-indexed language, level, recency, and topic slices.
@Observable
final class StudyModel {
    var due: DueResponse?
    var cards: [Card] = [] {
        didSet { rebuildIndex() }
    }
    var isLoading = false
    var errorMessage: String?

    private var cardsByLanguage: [CardLanguage: [Card]] = [:]
    private var cardsByLevel: [CardLanguage: [CardLevel: [Card]]] = [:]
    private var learningByLanguage: [CardLanguage: [Card]] = [:]
    private var recentByLanguage: [CardLanguage: [Card]] = [:]
    private var topicsByLanguage: [CardLanguage: [StudyTopicGroup]] = [:]

    private let service = StudyService()
    private let cardsService = CardsService()
    @ObservationIgnored private var lastLoadedAt: Date?

    var shouldRefreshOnAppear: Bool {
        guard !isLoading else { return false }
        guard let lastLoadedAt else { return true }
        return Date().timeIntervalSince(lastLoadedAt) > 20
    }

    init() {
        due = service.cachedDue()
        cards = cardsService.cachedList()
        rebuildIndex()
    }

    func cards(for language: CardLanguage) -> [Card] {
        cardsByLanguage[language] ?? []
    }

    func cards(for level: CardLevel, language: CardLanguage) -> [Card] {
        cardsByLevel[language]?[level] ?? []
    }

    func learningCards(for language: CardLanguage) -> [Card] {
        learningByLanguage[language] ?? []
    }

    func recentCards(for language: CardLanguage) -> [Card] {
        recentByLanguage[language] ?? []
    }

    func topicGroups(for language: CardLanguage) -> [StudyTopicGroup] {
        topicsByLanguage[language] ?? []
    }

    @MainActor
    func syncFromCache() {
        let cachedCards = cardsService.cachedList()
        if cachedCards != cards {
            cards = cachedCards
        }
        let cachedDue = service.cachedDue()
        if due?.cards.map(\.id) != cachedDue?.cards.map(\.id) || due?.count != cachedDue?.count {
            due = cachedDue
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil

        async let dueResult: Result<DueResponse, Error> = {
            do { return .success(try await service.due()) }
            catch { return .failure(error) }
        }()
        async let cardsResult: Result<[Card], Error> = {
            do { return .success(try await cardsService.list()) }
            catch { return .failure(error) }
        }()

        let (resolvedDue, resolvedCards) = await (dueResult, cardsResult)
        var firstError: Error?

        switch resolvedDue {
        case .success(let loadedDue):
            due = loadedDue
        case .failure(let error):
            if !(error is CancellationError) { firstError = error }
        }

        switch resolvedCards {
        case .success(let loadedCards):
            cards = loadedCards
        case .failure(let error):
            if !(error is CancellationError), firstError == nil { firstError = error }
        }

        if let firstError {
            errorMessage = (firstError as? ApiError)?.message ?? firstError.localizedDescription
        } else {
            lastLoadedAt = Date()
        }
        isLoading = false
    }

    private func rebuildIndex() {
        var byLanguage: [CardLanguage: [Card]] = [:]
        var byLevel: [CardLanguage: [CardLevel: [Card]]] = [:]
        var learning: [CardLanguage: [Card]] = [:]
        var byTopic: [CardLanguage: [String: [Card]]] = [:]
        var dates: [String: Date] = [:]

        for card in cards {
            let lang = card.cardLanguage
            byLanguage[lang, default: []].append(card)

            let level = CardLevel(card.level) ?? .new
            byLevel[lang, default: [:]][level, default: []].append(card)
            if level == .new || level == .learning {
                learning[lang, default: []].append(card)
            }

            if let topic = card.topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
                byTopic[lang, default: [:]][topic, default: []].append(card)
            }

            if let parsed = Self.parseDate(card.createdAt) {
                dates[card.slug] = parsed
            }
        }

        var recents: [CardLanguage: [Card]] = [:]
        var sortedTopics: [CardLanguage: [StudyTopicGroup]] = [:]

        for (lang, langCards) in byLanguage {
            let sortedRecent = langCards.sorted { lhs, rhs in
                switch (dates[lhs.slug], dates[rhs.slug]) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
            recents[lang] = Array(sortedRecent.prefix(20))

            let groups = (byTopic[lang] ?? [:]).map { StudyTopicGroup(topic: $0.key, cards: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.cards.count != rhs.cards.count { return lhs.cards.count > rhs.cards.count }
                    return lhs.topic.localizedCaseInsensitiveCompare(rhs.topic) == .orderedAscending
                }
            sortedTopics[lang] = groups
        }

        cardsByLanguage = byLanguage
        cardsByLevel = byLevel
        learningByLanguage = learning
        recentByLanguage = recents
        topicsByLanguage = sortedTopics
    }

    private static let isoFormatter = ISO8601DateFormatter()
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFormatter.date(from: raw) ?? isoFractionalFormatter.date(from: raw)
    }
}
