import SwiftUI

struct MacDailyLearningMetric: Identifiable, Equatable, Sendable {
    let id: String
    let day: String
    let reviewedCount: Int
    let practicedCount: Int
}

struct MacInsightsSnapshot: Equatable, Sendable {
    let reviewedThisWeek: Int
    let practicedThisWeek: Int
    let accuracyPercent: Int
    let streakDays: Int
    let difficultWordCount: Int
    let dailyMetrics: [MacDailyLearningMetric]

    static let preview = MacInsightsSnapshot(
        reviewedThisWeek: 84,
        practicedThisWeek: 36,
        accuracyPercent: 82,
        streakDays: 6,
        difficultWordCount: 8,
        dailyMetrics: [
            MacDailyLearningMetric(
                id: "monday",
                day: "Mon",
                reviewedCount: 12,
                practicedCount: 4
            ),
            MacDailyLearningMetric(
                id: "tuesday",
                day: "Tue",
                reviewedCount: 18,
                practicedCount: 8
            ),
            MacDailyLearningMetric(
                id: "wednesday",
                day: "Wed",
                reviewedCount: 9,
                practicedCount: 5
            ),
            MacDailyLearningMetric(
                id: "thursday",
                day: "Thu",
                reviewedCount: 16,
                practicedCount: 7
            ),
            MacDailyLearningMetric(
                id: "friday",
                day: "Fri",
                reviewedCount: 11,
                practicedCount: 3
            ),
            MacDailyLearningMetric(
                id: "saturday",
                day: "Sat",
                reviewedCount: 18,
                practicedCount: 9
            ),
            MacDailyLearningMetric(
                id: "sunday",
                day: "Sun",
                reviewedCount: 0,
                practicedCount: 0
            )
        ]
    )

    var totalActivityCount: Int {
        reviewedThisWeek + practicedThisWeek
    }

    var mostActiveDay: MacDailyLearningMetric? {
        dailyMetrics.max { left, right in
            let leftTotal = left.reviewedCount + left.practicedCount
            let rightTotal = right.reviewedCount + right.practicedCount
            return leftTotal < rightTotal
        }
    }
}

struct MacInsightsView: View {
    @Environment(MacActivityLedger.self) private var ledger
    @Environment(MacTodayStore.self) private var today
    @Environment(MacVocabularyStore.self) private var vocabulary

    private let overrideSnapshot: MacInsightsSnapshot?
    let reviewDifficultWords: () -> Void
    let startPractice: () -> Void

    init(
        snapshot: MacInsightsSnapshot? = nil,
        reviewDifficultWords: @escaping () -> Void = {},
        startPractice: @escaping () -> Void = {}
    ) {
        self.overrideSnapshot = snapshot
        self.reviewDifficultWords = reviewDifficultWords
        self.startPractice = startPractice
    }

    private var snapshot: MacInsightsSnapshot {
        if let overrideSnapshot {
            return overrideSnapshot
        }

        let live = ledger.insightsSnapshot(
            difficultWordCount: max(
                today.snapshot.difficultWordCount,
                vocabulary.items.filter {
                    $0.level?.lowercased() == "learning" || $0.isDue
                }.count
            )
        )

        if live.totalActivityCount == 0
            && ledger.reviewEvents.isEmpty
            && ledger.practiceEvents.isEmpty
            && vocabulary.items.isEmpty {
            return .preview
        }

        return live
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryGrid
                weeklyActivity
                vocabularyDistribution
                recommendations
            }
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle("Insights")
        .background(VocaDesign.subtleWindowBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Understand your learning rhythm and choose what to do next.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 175, maximum: 340), spacing: 16)
            ],
            spacing: 16
        ) {
            metricCard(
                title: "Reviewed",
                value: "\(snapshot.reviewedThisWeek)",
                detail: "cards this week",
                systemImage: "rectangle.stack.fill",
                tint: VocaDesign.brandGreen
            )

            metricCard(
                title: "Practiced",
                value: "\(snapshot.practicedThisWeek)",
                detail: "activities",
                systemImage: "sparkles",
                tint: VocaDesign.accentIndigo
            )

            metricCard(
                title: "Accuracy",
                value: "\(snapshot.accuracyPercent)%",
                detail: "recent answers",
                systemImage: "scope",
                tint: VocaDesign.accentSky
            )

            metricCard(
                title: "Streak",
                value: "\(snapshot.streakDays)",
                detail: snapshot.streakDays == 1 ? "day" : "days",
                systemImage: "flame.fill",
                tint: VocaDesign.accentAmber
            )
        }
    }

    private var weeklyActivity: some View {
        VocaSurfaceCard(padding: 24, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Activity")
                            .font(.system(size: 20, weight: .bold, design: .rounded))

                        Text("\(snapshot.totalActivityCount) learning actions in the last 7 days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let mostActiveDay = snapshot.mostActiveDay,
                       (mostActiveDay.reviewedCount + mostActiveDay.practicedCount) > 0 {
                        VocaPillBadge(
                            text: "Most active: \(mostActiveDay.day)",
                            icon: "chart.bar.fill",
                            tint: VocaDesign.brandGreen
                        )
                    }
                }

                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(snapshot.dailyMetrics) { metric in
                        activityColumn(metric)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)

                HStack(spacing: 18) {
                    legend(
                        title: "Review",
                        color: VocaDesign.brandGreen
                    )

                    legend(
                        title: "Practice",
                        color: VocaDesign.accentIndigo
                    )
                }
                .font(.caption.weight(.medium))
            }
        }
    }

    private var vocabularyDistribution: some View {
        let englishCount = vocabulary.items.filter { $0.language == .english }.count
        let chineseCount = vocabulary.items.filter { $0.language == .chinese }.count
        let favoriteCount = vocabulary.items.filter(\.isFavorite).count
        let dueCount = vocabulary.items.filter(\.isDue).count

        return VocaSurfaceCard(padding: 20, cornerRadius: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    HStack(spacing: 14) {
                        VocaIconBadge(
                            systemImage: "books.vertical.fill",
                            tint: VocaDesign.accentSky,
                            size: 42,
                            iconSize: 18
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library Breakdown")
                                .font(.headline)
                            Text("\(vocabulary.items.count) total saved words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    statPill(label: "English", value: "\(englishCount)", tint: VocaDesign.accentSky)
                    statPill(label: "Chinese", value: "\(chineseCount)", tint: VocaDesign.accentAmber)
                    statPill(label: "Favorites", value: "\(favoriteCount)", tint: VocaDesign.accentRose)
                    statPill(label: "Due Now", value: "\(dueCount)", tint: VocaDesign.brandGreen)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        VocaIconBadge(
                            systemImage: "books.vertical.fill",
                            tint: VocaDesign.accentSky,
                            size: 42,
                            iconSize: 18
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library Breakdown")
                                .font(.headline)
                            Text("\(vocabulary.items.count) total saved words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 110, maximum: 200), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        statPill(label: "English", value: "\(englishCount)", tint: VocaDesign.accentSky)
                        statPill(label: "Chinese", value: "\(chineseCount)", tint: VocaDesign.accentAmber)
                        statPill(label: "Favorites", value: "\(favoriteCount)", tint: VocaDesign.accentRose)
                        statPill(label: "Due Now", value: "\(dueCount)", tint: VocaDesign.brandGreen)
                    }
                }
            }
        }
    }

    private func statPill(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Next")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 640), spacing: 16)
                ],
                spacing: 16
            ) {
                recommendationCard(
                    title: "Review Difficult Words",
                    detail: "\(snapshot.difficultWordCount) words need more attention.",
                    systemImage: "bolt.heart.fill",
                    tint: VocaDesign.accentRose,
                    buttonTitle: "Start Review",
                    action: reviewDifficultWords
                )

                recommendationCard(
                    title: "Practice for Accuracy",
                    detail: "A short session can reinforce recent vocabulary.",
                    systemImage: "target",
                    tint: VocaDesign.brandGreen,
                    buttonTitle: "Practice",
                    action: startPractice
                )
            }
        }
    }

    private func metricCard(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VocaSurfaceCard(padding: 18, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VocaIconBadge(
                        systemImage: systemImage,
                        tint: tint,
                        size: 36,
                        iconSize: 16
                    )
                    Spacer()
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func activityColumn(
        _ metric: MacDailyLearningMetric
    ) -> some View {
        let maximumValue = max(
            snapshot.dailyMetrics.map {
                $0.reviewedCount + $0.practicedCount
            }.max() ?? 1,
            1
        )
        let total = metric.reviewedCount + metric.practicedCount
        let availableHeight: CGFloat = 160
        let reviewHeight = availableHeight
            * CGFloat(metric.reviewedCount)
            / CGFloat(maximumValue)
        let practiceHeight = availableHeight
            * CGFloat(metric.practicedCount)
            / CGFloat(maximumValue)

        return VStack(spacing: 8) {
            Spacer(minLength: 0)

            Text("\(total)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(total == 0 ? 0 : 1)

            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(VocaDesign.accentIndigo)
                    .frame(height: practiceHeight)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(VocaDesign.brandGradient)
                    .frame(height: reviewHeight)
            }
            .frame(maxWidth: 46)

            Text(metric.day)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.day)
        .accessibilityValue(
            "\(metric.reviewedCount) reviewed, "
            + "\(metric.practicedCount) practiced"
        )
    }

    private func legend(
        title: String,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
        }
        .accessibilityElement(children: .combine)
    }

    private func recommendationCard(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VocaSurfaceCard(padding: 20, cornerRadius: 16) {
            HStack(spacing: 16) {
                VocaIconBadge(
                    systemImage: systemImage,
                    tint: tint,
                    size: 44,
                    iconSize: 19
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(buttonTitle, action: action)
                    .buttonStyle(VocaSecondaryButtonStyle(tint: tint))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        MacInsightsView(snapshot: .preview)
            .environment(MacActivityLedger())
            .environment(MacTodayStore())
            .environment(MacVocabularyStore())
            .frame(width: 1080, height: 760)
    }
}
