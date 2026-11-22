import SwiftUI

/// Full-featured Hands-Free Vocabulary Radio sheet + compact Now Playing mini-bar.
struct VocabRadioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner

    @State private var radio = VocabRadioPlayer.shared

    var body: some View {
        @Bindable var bindableRadio = radio

        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        nowPlayingStageCard

                        transportControlsCard

                        timelineCustomizationCard(bindableRadio: $bindableRadio)
                    }
                    .padding()
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Đài phát từ vựng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        radio.stop()
                        dismiss()
                    } label: {
                        Text("Dừng hẳn")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thu nhỏ") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 1. Now Playing Stage Card

    @ViewBuilder private var nowPlayingStageCard: some View {
        if let card = radio.currentCard {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    VocaPillBadge(
                        text: "\(radio.deckTitle) · \(radio.currentIndex + 1)/\(max(radio.queue.count, 1))",
                        icon: "headphones",
                        tint: Brand.green
                    )

                    if let sleepSummary = radio.remainingSleepSummary {
                        VocaPillBadge(
                            text: sleepSummary,
                            icon: "moon.zzz.fill",
                            tint: .indigo
                        )
                    }

                    Spacer()

                    Button {
                        Haptics.selection()
                        learner.toggleFavorite(card.slug)
                    } label: {
                        Image(systemName: learner.isFavorite(card.slug) ? "star.fill" : "star")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(learner.isFavorite(card.slug) ? .orange : .secondary)
                            .frame(width: 32, height: 32)
                            .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Yêu thích")
                }

                // Live Step Indicator Pill
                HStack(spacing: 8) {
                    Image(systemName: radio.step.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Brand.green)
                        .symbolEffect(.pulse, isActive: radio.isPlaying)
                    Text(radio.step.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Brand.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Brand.greenSoft, in: Capsule())

                // Word / Mi-Grid Hanzi Hero
                VStack(spacing: 10) {
                    if card.isChinese && theme.hanziCalligraphic {
                        HanziFlashcardWordView(word: card.word, isFront: true)
                    } else {
                        Text(card.word)
                            .font(card.isChinese
                                  ? VocaTypography.hanziFont(size: 54, weight: .bold, isCalligraphic: theme.hanziCalligraphic)
                                  : .system(size: 38, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                    }

                    if let phonetic = card.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(card.isChinese ? .title3.weight(.medium) : .system(.title3, design: .monospaced))
                            .foregroundStyle(card.isChinese ? Brand.green : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(Brand.elevatedFill(for: colorScheme), in: Capsule())
                    }
                }
                .padding(.vertical, 6)

                Divider().opacity(0.6)

                // Vietnamese Meaning & Example Stage
                VStack(spacing: 10) {
                    if radio.shouldShowMeaningNow {
                        if let meaning = VocabRadioPlayer.cleanMeaning(for: card) {
                            Text(meaning)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        if radio.speakExample, let ex = VocabRadioPlayer.firstExampleDisplay(for: card) {
                            VStack(spacing: 3) {
                                Text("“\(ex.primary)”")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                if let sub = ex.secondary {
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary.opacity(0.85))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.top, 2)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.orange)
                            Text("Đang ẩn nghĩa để bạn tự nhẩm trong đầu…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: radio.shouldShowMeaningNow)

                if let next = radio.nextCardPreview {
                    HStack(spacing: 6) {
                        Text("Tiếp theo:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(next.word)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                        if let phonetic = next.phonetic, !phonetic.isEmpty {
                            Text("(\(phonetic))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .brandHeroCard(padding: 20, cornerRadius: 24)
        } else {
            ContentUnavailableView(
                "Chưa có thẻ trong danh sách phát",
                systemImage: "headphones",
                description: Text("Chọn một bộ thẻ trong màn hình Ôn tập để bắt đầu nghe thụ động.")
            )
        }
    }

    // MARK: - 2. Transport Controls

    private var transportControlsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 24) {
                Button {
                    radio.shuffleQueue()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 42)
                        .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                }
                .buttonStyle(PressableScaleStyle(scale: 0.92))
                .accessibilityLabel("Xáo trộn danh sách")

                Button {
                    radio.previousCard()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 50)
                        .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                }
                .buttonStyle(PressableScaleStyle(scale: 0.92))
                .accessibilityLabel("Từ trước")

                Button {
                    Haptics.impact(.medium)
                    radio.togglePlayPause()
                } label: {
                    Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Brand.gradient, in: Circle())
                        .shadow(color: Brand.green.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(PressableScaleStyle(scale: 0.94))
                .accessibilityLabel(radio.isPlaying ? "Tạm dừng" : "Phát")

                Button {
                    radio.nextCard()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 50, height: 50)
                        .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                }
                .buttonStyle(PressableScaleStyle(scale: 0.92))
                .accessibilityLabel("Từ tiếp theo")

                Menu {
                    Picker("Hẹn giờ tắt", selection: Binding(
                        get: { radio.sleepTimer },
                        set: { radio.sleepTimer = $0 }
                    )) {
                        ForEach(VocabRadioPlayer.SleepTimerOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: radio.sleepTimer == .off ? "moon.zzz" : "moon.zzz.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(radio.sleepTimer == .off ? Color.secondary : Color.indigo)
                        .frame(width: 42, height: 42)
                        .background(
                            radio.sleepTimer == .off
                                ? AnyShapeStyle(Brand.elevatedFill(for: colorScheme))
                                : AnyShapeStyle(Color.indigo.opacity(0.15)),
                            in: Circle()
                        )
                }
                .accessibilityLabel("Hẹn giờ tự tắt")
            }

            Text("Hỗ trợ khóa màn hình, Control Center và bóp tai nghe AirPods (1 lần: Dừng/Phát · 2 lần: Qua từ mới · 3 lần: Lùi lại).")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .brandCard(padding: 16, cornerRadius: 20)
    }

    // MARK: - 3. Audio Timeline Customization

    private func timelineCustomizationCard(bindableRadio: Bindable<VocabRadioPlayer>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Kịch bản đọc tự động", systemImage: "slider.horizontal.3")
                .font(.headline)

            Stepper(value: bindableRadio.wordRepeatCount, in: 1...3) {
                HStack {
                    Text("Đọc từ vựng")
                    Spacer()
                    Text("\(radio.wordRepeatCount) lần")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Brand.green)
                }
            }

            Divider().opacity(0.55)

            Stepper(
                value: bindableRadio.thinkingDelaySeconds,
                in: VocabRadioPlayer.thinkingDelayRange,
                step: 0.5
            ) {
                HStack {
                    Text("Nghỉ để tự nhẩm nghĩa")
                    Spacer()
                    Text(ThemeStore.formatDelay(radio.thinkingDelaySeconds))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Brand.green)
                }
            }

            Divider().opacity(0.55)

            Toggle("Đọc nghĩa tiếng Việt (vi-VN)", isOn: bindableRadio.speakMeaningVi)
                .tint(Brand.green)

            Divider().opacity(0.55)

            Toggle("Đọc câu ví dụ", isOn: bindableRadio.speakExample)
                .tint(Brand.green)

            Divider().opacity(0.55)

            Toggle("Ẩn nghĩa trên màn hình cho tới khi đọc", isOn: bindableRadio.hideMeaningDuringPause)
                .tint(Brand.green)
        }
        .brandCard(padding: 16, cornerRadius: 20)
    }
}

/// Compact mini player bar shown in `StudyRootView` whenever `VocabRadioPlayer` is active in the background.
struct VocabRadioMiniBar: View {
    @Environment(\.colorScheme) private var colorScheme
    var onExpand: () -> Void

    @State private var radio = VocabRadioPlayer.shared

    var body: some View {
        if radio.isActive, let card = radio.currentCard {
            HStack(spacing: 12) {
                Button(action: onExpand) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Brand.greenSoft)
                                .frame(width: 40, height: 40)
                            Image(systemName: radio.step.icon)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Brand.green)
                                .symbolEffect(.pulse, isActive: radio.isPlaying)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(card.word)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("· \(radio.currentIndex + 1)/\(radio.queue.count)")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Text(radio.step.title)
                                .font(.caption)
                                .foregroundStyle(Brand.green)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Button {
                        Haptics.selection()
                        radio.togglePlayPause()
                    } label: {
                        Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Brand.green, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(radio.isPlaying ? "Tạm dừng đài" : "Phát tiếp")

                    Button {
                        radio.nextCard()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Từ tiếp theo")

                    Button {
                        Haptics.selection()
                        radio.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tắt đài từ vựng")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Brand.green.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
            )
        }
    }
}
