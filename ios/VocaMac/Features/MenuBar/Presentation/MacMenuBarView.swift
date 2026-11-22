import AppKit
import SwiftUI

struct MacMenuBarView: View {
    private enum Mode: Equatable {
        case overview
        case miniReview
        case shortcuts
    }

    private enum MiniReviewPhase: Equatable {
        case prompt
        case revealed
        case completed
    }

    private struct GradedMiniCard: Equatable {
        let card: MacReviewCard
        let grade: MacReviewGrade
    }

    @Environment(MacAppRouter.self) private var router
    @Environment(MacSessionStore.self) private var session
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacTodayStore.self) private var today
    @Environment(MacReviewStore.self) private var review
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    // Search & Inline Peek
    @ViewState private var activeMode: Mode = .overview
    @ViewState private var quickQuery = ""
    @ViewState private var selectedResultID: MacVocabularyItem.ID?
    @ViewState private var hoveredResultID: MacVocabularyItem.ID?
    @ViewState private var peekedItemID: MacVocabularyItem.ID?
    @ViewState private var aiCreateLanguage: MacVocabularyItem.Language = .english
    @ViewState private var isCreatingInline = false
    @ViewState private var clipboardCandidate: String?
    @ViewState private var dismissedClipboardCandidate: String?
    @ViewState private var spotlightOffset = 0
    @ViewState private var toast: (icon: String, message: String, tint: Color)?
    @FocusState private var isSearchFocused: Bool

    // Inline Mini Review (up to 5 cards)
    @ViewState private var miniQueue: [MacReviewCard] = []
    @ViewState private var miniIndex = 0
    @ViewState private var miniPhase: MiniReviewPhase = .prompt
    @ViewState private var miniHistory: [GradedMiniCard] = []
    @ViewState private var isMiniPracticeFallback = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 11) {
                header

                if session.phase == .loading {
                    loadingContent
                } else if !session.isSignedIn {
                    signedOutContent
                } else {
                    switch activeMode {
                    case .overview:
                        overviewAndSearchContent
                    case .miniReview:
                        miniReviewContent
                    case .shortcuts:
                        shortcutsCheatsheetContent
                    }
                }

                Divider()
                    .opacity(0.5)

                footer
            }
            .padding(14)

            if let toast {
                miniToastView(toast)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }

            hiddenKeyboardShortcuts
        }
        .frame(width: 376)
        .task {
            configureGlobalIntegrations()
            await session.bootstrap()
            if session.isSignedIn {
                await refreshDataIfNeeded(force: false)
            }
        }
        .onAppear {
            MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: preferences.hideDockIcon)
            configureGlobalIntegrations()
            inspectClipboardCandidate()
            if activeMode == .overview && peekedItem == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            inspectClipboardCandidate()
            if activeMode == .overview && peekedItem == nil {
                isSearchFocused = true
            }
        }
        .onChange(of: quickQuery) { _, newValue in
            if VocaDesign.containsHanCharacters(newValue) {
                aiCreateLanguage = .chinese
            }
            if !newValue.isEmpty {
                peekedItemID = nil
            }
            selectedResultID = matchedItems.first?.id
        }
    }

    // MARK: - 1. Header

    private var header: some View {
        HStack(spacing: 10) {
            VocaBrandMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Voca Dictionary")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if session.isSignedIn, today.snapshot.streakDays > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(today.snapshot.streakDays)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.13), in: Capsule())
                .help("Chuỗi học liên tục \(today.snapshot.streakDays) ngày")
            }

            if session.isSignedIn {
                syncStatusPill
            }

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    activeMode = (activeMode == .shortcuts) ? .overview : .shortcuts
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(activeMode == .shortcuts ? VocaDesign.brandGreen : .secondary)
                    .frame(width: 25, height: 25)
                    .background(
                        activeMode == .shortcuts
                            ? VocaDesign.brandGreen.opacity(0.15)
                            : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .help("Bảng phím tắt Menu Bar (⌘/)")
        }
    }

    private var headerSubtitle: String {
        guard session.isSignedIn else {
            return "Trợ lý học từ vựng trên macOS"
        }
        return "\(vocabulary.items.count) từ · Mục tiêu \(today.snapshot.completedGoalCount)/\(today.snapshot.dailyGoal)"
    }

    private var syncStatusPill: some View {
        let isSyncing = vocabulary.isLoading || today.isLoading || review.isLoading
        let pending = vocabulary.pendingMutationCount
        let dotColor: Color = isSyncing
            ? VocaDesign.accentSky
            : (pending > 0 ? VocaDesign.accentAmber : VocaDesign.brandGreen)
        let label: String = isSyncing
            ? "Sync…"
            : (pending > 0 ? "\(pending) chờ" : "Synced")

        return HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    // MARK: - 2. Loading & Signed Out States

    private var loadingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Đang đồng bộ phiên làm việc…")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Đăng nhập để đồng bộ kho từ vựng, tra từ tức thì và ôn tập nhanh ngay trên thanh Menu Bar.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                activateMainWindow(destination: .today)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Mở Voca & Đăng nhập")
                    Spacer()
                    VocaKeycap(label: "⌘O")
                }
            }
            .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
        }
        .padding(12)
        .background(glassCardSurface())
    }

    // MARK: - 3. Overview, Instant Search & Inline Peek

    private var overviewAndSearchContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickSearchField

            if let peekedItem {
                inlinePeekCard(peekedItem)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if !trimmedQuery.isEmpty {
                searchResultsSection
            } else {
                if let candidate = activeClipboardSuggestion {
                    clipboardSuggestionBar(candidate)
                }

                dueSummaryCard

                if let word = spotlightWord {
                    wordOfTheDayCard(word)
                }

                quickShortcutLauncherGrid
            }
        }
    }

    private var quickSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isSearchFocused ? VocaDesign.brandGreen : .secondary)

            TextField("Tra nhanh hoặc gõ từ mới để thêm…", text: $quickQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)
                .onSubmit {
                    handleSearchSubmit()
                }

            if !quickQuery.isEmpty {
                Button {
                    quickQuery = ""
                    peekedItemID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Xóa tìm kiếm (Esc)")
            } else if !isSearchFocused {
                VocaKeycap(label: "⌘F")
            }

            // Target language pill for AI creation (`⌘L`)
            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    aiCreateLanguage = (aiCreateLanguage == .english) ? .chinese : .english
                }
            } label: {
                Text(aiCreateLanguage == .chinese ? "🇨🇳 中文" : "🇺🇸 EN")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Đổi ngôn ngữ tạo thẻ AI: Tiếng Anh / Tiếng Trung (⌘L)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7.5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSearchFocused
                        ? VocaDesign.brandGreen.opacity(0.75)
                        : Color.primary.opacity(0.12),
                    lineWidth: isSearchFocused ? 1.4 : 1
                )
        )
    }

    private func clipboardSuggestionBar(_ candidate: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 11))
                .foregroundStyle(VocaDesign.brandGreen)

            Text("Bộ nhớ tạm:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("“\(candidate)”")
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("Tra ngay") {
                quickQuery = candidate
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(VocaDesign.brandGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(VocaDesign.brandGreen.opacity(0.14), in: Capsule())
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    dismissedClipboardCandidate = candidate
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Ẩn gợi ý này")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(glassCardSurface(tint: VocaDesign.brandGreen, tintOpacity: 0.06))
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let displayed = Array(matchedItems.prefix(5))

            if !displayed.isEmpty {
                ForEach(displayed) { item in
                    let isSelected = (selectedResultID ?? displayed.first?.id) == item.id
                    let isHovered = hoveredResultID == item.id

                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(item.term)
                                    .font(
                                        item.language == .chinese
                                            ? VocaDesign.hanziFont(size: 18, weight: .bold)
                                            : .system(size: 13, weight: .bold, design: .rounded)
                                    )
                                    .lineLimit(1)

                                if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
                                    Text(pronunciation)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(
                                            item.language == .chinese ? VocaDesign.brandGreen : .secondary
                                        )
                                        .lineLimit(1)
                                }

                                if item.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(VocaDesign.accentAmber)
                                }
                            }

                            Text(item.displayMeaningVi)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        if isSelected {
                            VocaKeycap(label: "↩")
                        }

                        Button {
                            speech.toggle(item.term, language: item.language)
                        } label: {
                            Image(
                                systemName: speech.isSpeaking && speech.speakingText == item.term
                                    ? "stop.fill"
                                    : "speaker.wave.2.fill"
                            )
                            .font(.system(size: 11))
                            .foregroundStyle(VocaDesign.brandGreen)
                            .frame(width: 24, height: 24)
                            .background(VocaDesign.brandGreen.opacity(0.13), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Nghe phát âm (⌘P)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                isSelected
                                    ? VocaDesign.brandGreen.opacity(0.12)
                                    : (isHovered ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? VocaDesign.brandGreen.opacity(0.45)
                                    : Color.primary.opacity(0.07),
                                lineWidth: 1
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .onHover { hovering in
                        hoveredResultID = hovering ? item.id : nil
                    }
                    .onTapGesture {
                        selectedResultID = item.id
                        withAnimation(.snappy(duration: 0.18)) {
                            peekedItemID = item.id
                        }
                    }
                }
            }

            if !hasExactMatch {
                Button {
                    createQuickWord()
                } label: {
                    HStack(spacing: 6) {
                        if isCreatingInline {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        Text(
                            isCreatingInline
                                ? "Đang tạo “\(trimmedQuery)” bằng AI…"
                                : "Tạo thẻ \(aiCreateLanguage == .chinese ? "Hán ngữ" : "Tiếng Anh") “\(trimmedQuery)”"
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        Spacer()
                        Text(matchedItems.isEmpty ? "↩" : "⇧↩")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                .disabled(isCreatingInline)
            }
        }
    }

    // MARK: - Inline Quick Peek Card (No Main Window Needed)

    private func inlinePeekCard(_ item: MacVocabularyItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        peekedItemID = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text(trimmedQuery.isEmpty ? "Quay lại" : "Kết quả")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Quay lại (Esc)")

                Spacer()

                miniIconAction(
                    icon: item.isFavorite ? "star.fill" : "star",
                    tint: item.isFavorite ? VocaDesign.accentAmber : .secondary,
                    tooltip: "Yêu thích (⌘D)"
                ) {
                    toggleFavorite(item)
                }

                miniIconAction(
                    icon: "doc.on.doc",
                    tint: .secondary,
                    tooltip: "Sao chép (⌘C)"
                ) {
                    copyItem(item)
                }

                miniIconAction(
                    icon: speech.isSpeaking && speech.speakingText == item.term
                        ? "stop.fill"
                        : "speaker.wave.2.fill",
                    tint: VocaDesign.brandGreen,
                    tooltip: "Phát âm (⌘P)"
                ) {
                    speech.toggle(item.term, language: item.language)
                }

                Button {
                    openVocabularyItem(item)
                } label: {
                    HStack(spacing: 3) {
                        Text("Chi tiết")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(VocaDesign.brandGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VocaDesign.brandGreen.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Mở trong cửa sổ Voca (⌘↩)")
            }

            if item.language == .chinese, VocaDesign.containsHanCharacters(item.term) {
                MacHanziWritingGuide(
                    word: item.term,
                    compact: true,
                    tileSize: 38
                )
            } else {
                Text(item.term)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .textSelection(.enabled)
            }

            HStack(spacing: 6) {
                if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(item.language == .chinese ? VocaDesign.brandGreen : .secondary)
                        .textSelection(.enabled)
                }

                if let pos = item.partOfSpeech, !pos.isEmpty {
                    Text(pos)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }

            Text(item.displayMeaningVi)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let meaningEn = item.meaningEn,
               !meaningEn.isEmpty,
               meaningEn != item.displayMeaningVi {
                Text(meaningEn)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let firstExample = item.examples.first, !firstExample.isEmpty {
                let parsed = item.language == .chinese ? ChineseExample(firstExample) : nil
                let spokenText = parsed?.hanzi ?? firstExample
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(VocaDesign.brandGreen.opacity(0.65))
                        .frame(width: 2.5)

                    if let parsed {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parsed.hanzi)
                                .font(VocaDesign.hanziFont(size: 13.5, weight: .bold))
                                .foregroundStyle(.primary)
                            if let pinyin = parsed.pinyin {
                                Text(pinyin)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(VocaDesign.brandGreen)
                            }
                            if let meaningVi = parsed.meaningVi {
                                Text(meaningVi)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(firstExample)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        speech.toggle(spokenText, language: item.language)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe câu ví dụ")
                }
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(glassCardSurface())
    }

    // MARK: - 4. Due Hero, Word of the Day & Quick Shortcuts Grid

    private var effectiveDueCount: Int {
        max(today.snapshot.dueCount, review.cards.count)
    }

    private var dueSummaryCard: some View {
        let dueCount = effectiveDueCount

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dueCount > 0 ? "\(dueCount) thẻ cần ôn tập" : "Đã hoàn thành ôn tập ✓")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(dueCount > 0 ? .primary : VocaDesign.brandGreen)

                    Text(dueLanguageSubtitle(dueCount: dueCount))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    openReviewFocusWindow()
                } label: {
                    HStack(spacing: 3) {
                        Text("Phòng ôn")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Mở cửa sổ ôn tập tập trung (⌘3)")
            }

            ProgressView(value: min(max(today.snapshot.goalProgress, 0), 1))
                .tint(VocaDesign.brandGreen)

            HStack(spacing: 8) {
                Button {
                    startMiniReview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: dueCount > 0 ? "bolt.fill" : "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text(
                            dueCount > 0
                                ? "Ôn nhanh \(min(dueCount, 5)) thẻ"
                                : "Ôn nhẩm 5 từ"
                        )
                        .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("⌘R")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                .disabled(dueCount == 0 && vocabulary.items.isEmpty)
            }
        }
        .padding(11)
        .background(
            glassCardSurface(
                tint: dueCount > 0 ? VocaDesign.brandGreen : nil,
                tintOpacity: 0.06
            )
        )
    }

    private func dueLanguageSubtitle(dueCount: Int) -> String {
        if dueCount > 0, !review.cards.isEmpty {
            let en = review.cards.filter { $0.language == .english }.count
            let zh = review.cards.filter { $0.language == .chinese }.count
            if en > 0 && zh > 0 {
                return "\(en) English · \(zh) 中文"
            }
        }
        return "Hôm nay: \(today.snapshot.completedGoalCount)/\(today.snapshot.dailyGoal) hoạt động"
    }

    private func wordOfTheDayCard(_ item: MacVocabularyItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("TỪ VỰNG HÔM NAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                if item.isDue {
                    Text("Đến hạn")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(VocaDesign.accentAmber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(VocaDesign.accentAmber.opacity(0.14), in: Capsule())
                }

                Spacer()

                miniIconAction(
                    icon: item.isFavorite ? "star.fill" : "star",
                    tint: item.isFavorite ? VocaDesign.accentAmber : .secondary,
                    tooltip: "Yêu thích (⌘D)"
                ) {
                    toggleFavorite(item)
                }

                miniIconAction(
                    icon: "arrow.triangle.2.circlepath",
                    tint: .secondary,
                    tooltip: "Đổi từ khác (⇧⌘R)"
                ) {
                    withAnimation(.snappy(duration: 0.2)) {
                        spotlightOffset += 1
                    }
                }

                miniIconAction(
                    icon: speech.isSpeaking && speech.speakingText == item.term
                        ? "stop.fill"
                        : "speaker.wave.2.fill",
                    tint: VocaDesign.brandGreen,
                    tooltip: "Phát âm (⌘P)"
                ) {
                    speech.toggle(item.term, language: item.language)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.term)
                    .font(
                        item.language == .chinese
                            ? VocaDesign.hanziFont(size: 22, weight: .bold)
                            : .system(size: 15.5, weight: .bold, design: .rounded)
                    )
                    .lineLimit(1)

                if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(item.language == .chinese ? VocaDesign.brandGreen : .secondary)
                        .lineLimit(1)
                }
            }

            Text(item.displayMeaningVi)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCardSurface())
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture {
            withAnimation(.snappy(duration: 0.18)) {
                peekedItemID = item.id
            }
        }
        .help("Nhấn để xem nhanh nghĩa & ví dụ ngay tại đây")
    }

    private var quickShortcutLauncherGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LỐI TẮT NHANH")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘1…6 mở màn hình")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 7),
                    GridItem(.flexible(), spacing: 7)
                ],
                spacing: 7
            ) {
                shortcutActionTile(
                    icon: "sparkle.magnifyingglass",
                    title: "Tra từ nổi",
                    shortcut: preferences.quickLookupHotkey.badgeLabel,
                    tint: VocaDesign.brandGreen
                ) {
                    MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
                    MacQuickLookupPanelController.shared.toggleFloatingPanel()
                }

                shortcutActionTile(
                    icon: "plus.circle.fill",
                    title: "Thêm từ AI",
                    shortcut: "⌘N",
                    tint: VocaDesign.accentSky
                ) {
                    activateMainWindow(destination: .vocabulary)
                    router.requestAddWord()
                }

                shortcutActionTile(
                    icon: "doc.viewfinder",
                    title: "Nhập / OCR",
                    shortcut: "⇧⌘I",
                    tint: VocaDesign.accentAmber
                ) {
                    activateMainWindow(destination: .vocabulary)
                    router.requestImportExport(mode: .importWords)
                }

                shortcutActionTile(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Gia sư AI",
                    shortcut: "⌘5",
                    tint: VocaDesign.brandTeal
                ) {
                    activateMainWindow(destination: .assistant)
                }
            }
        }
    }

    private func shortcutActionTile(
        icon: String,
        title: String,
        shortcut: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                VocaKeycap(label: shortcut)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6.5)
            .background(glassCardSurface())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Inline Mini Review (5 Cards Right in Menu Bar)

    private var currentMiniCard: MacReviewCard? {
        guard !miniQueue.isEmpty, miniIndex < miniQueue.count else { return nil }
        return miniQueue[miniIndex]
    }

    private var miniReviewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        activeMode = .overview
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Quay lại")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Đóng ôn nhanh (Esc)")

                if miniPhase != .completed {
                    Text("\(min(miniIndex + 1, miniQueue.count)) / \(miniQueue.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(VocaDesign.brandGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(VocaDesign.brandGreen.opacity(0.12), in: Capsule())
                }

                Spacer()

                if !miniHistory.isEmpty && miniPhase != .completed && !isMiniPracticeFallback {
                    miniIconAction(
                        icon: "arrow.uturn.backward",
                        tint: .secondary,
                        tooltip: "Xem lại thẻ trước (⌘Z)"
                    ) {
                        undoLastMiniCard()
                    }
                }

                if let card = currentMiniCard, miniPhase != .completed {
                    miniIconAction(
                        icon: speech.isSpeaking && speech.speakingText == card.prompt
                            ? "stop.fill"
                            : "speaker.wave.2.fill",
                        tint: VocaDesign.brandGreen,
                        tooltip: "Nghe phát âm (⌘P)"
                    ) {
                        speech.toggle(card.prompt, language: card.language)
                    }
                }

                Button {
                    openReviewFocusWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Mở cửa sổ ôn tập đầy đủ")
            }

            if miniPhase == .completed {
                miniReviewCompletedCard
            } else if let card = currentMiniCard {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text(card.prompt)
                            .font(
                                card.language == .chinese
                                    ? VocaDesign.hanziFont(size: 36, weight: .bold)
                                    : .system(size: 26, weight: .bold, design: .rounded)
                            )
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)

                        if let pronunciation = card.pronunciation, !pronunciation.isEmpty {
                            Text(pronunciation)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(card.language == .chinese ? VocaDesign.brandGreen : .secondary)
                        }

                        if miniPhase == .prompt {
                            Text("Nhấn Space hoặc chạm thẻ để lật đáp án")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, miniPhase == .prompt ? 22 : 10)

                    if miniPhase == .revealed {
                        Divider().opacity(0.5)

                        VStack(spacing: 6) {
                            Text(card.meaning)
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundStyle(VocaDesign.brandGreen)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            if let example = card.example, !example.isEmpty {
                                let parsed = card.language == .chinese ? ChineseExample(example) : nil
                                Text(parsed.map { [$0.hanzi, $0.pinyin, $0.meaningVi].compactMap { $0 }.joined(separator: " · ") } ?? example)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .italic()
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(glassCardSurface(tint: miniPhase == .revealed ? VocaDesign.brandGreen : nil, tintOpacity: 0.05))
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .onTapGesture {
                    if miniPhase == .prompt {
                        revealMiniCard()
                    }
                }

                if miniPhase == .prompt {
                    Button {
                        revealMiniCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                            Text("Hiện đáp án")
                            Spacer()
                            Text("Space")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                } else {
                    HStack(spacing: 6) {
                        ForEach(MacReviewGrade.allCases) { grade in
                            Button {
                                submitMiniGrade(grade)
                            } label: {
                                VStack(spacing: 3) {
                                    Text(grade.title)
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundStyle(grade.tint)
                                    Text(String(grade.keyboardKey.character))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(grade.tint.opacity(0.11))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(grade.tint.opacity(0.28), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var miniReviewCompletedCard: some View {
        VStack(spacing: 12) {
            VocaIconBadge(
                systemImage: "checkmark.seal.fill",
                tint: VocaDesign.brandGreen,
                size: 46,
                iconSize: 22
            )

            Text("Hoàn thành \(miniQueue.count) thẻ! 🎉")
                .font(.system(size: 15, weight: .bold, design: .rounded))

            Text(
                effectiveDueCount > 0
                    ? "Còn \(effectiveDueCount) thẻ đến hạn hôm nay."
                    : "Bạn đã hoàn thành toàn bộ thẻ đến hạn!"
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if effectiveDueCount > 0 {
                    Button {
                        startMiniReview()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                            Text("Ôn tiếp 5 thẻ")
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                }

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        activeMode = .overview
                    }
                } label: {
                    Text("Xong")
                }
                .buttonStyle(VocaSecondaryButtonStyle(isFullWidth: effectiveDueCount == 0))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(glassCardSurface(tint: VocaDesign.brandGreen, tintOpacity: 0.06))
    }

    // MARK: - 6. Inline Shortcuts Cheatsheet (`⌘/`)

    private var shortcutsCheatsheetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PHÍM TẮT MENU BAR & HỆ THỐNG")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Đóng (Esc)") {
                    withAnimation(.snappy(duration: 0.18)) {
                        activeMode = .overview
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VocaDesign.brandGreen)
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                shortcutLegendRow("Đặt con trỏ tìm kiếm", keys: ["⌘F"])
                shortcutLegendRow("Chọn từ / Xem nhanh", keys: ["↑↓", "↩"])
                shortcutLegendRow("Đổi ngôn ngữ tạo từ AI", keys: ["⌘L"])
                shortcutLegendRow("Ôn nhanh 5 thẻ tại chỗ", keys: ["⌘R"])
                shortcutLegendRow("Lật thẻ & Chấm điểm ôn", keys: ["Space", "1–4"])
                shortcutLegendRow("Phát âm / Yêu thích / Chép", keys: ["⌘P", "⌘D", "⌘C"])
                shortcutLegendRow("Đổi từ vựng hôm nay", keys: ["⇧⌘R"])
                shortcutLegendRow("Mở bảng Tra từ nổi mọi nơi", keys: [preferences.quickLookupHotkey.badgeLabel])
                shortcutLegendRow("Chuyển 6 màn hình chính", keys: ["⌘1…6"])
                shortcutLegendRow("Mở Voca / Cài đặt / Thoát", keys: ["⌘O", "⌘,", "⌘Q"])
            }
            .padding(11)
            .background(glassCardSurface())
        }
    }

    private func shortcutLegendRow(_ title: String, keys: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    VocaKeycap(label: key)
                }
            }
        }
    }

    // MARK: - 7. Footer & System Gear Menu

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                activateMainWindow(destination: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Mở Voca")
                        .font(.system(size: 12, weight: .semibold))
                    Text("⌘O")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .opacity(0.85)
                }
            }
            .buttonStyle(VocaPrimaryButtonStyle())

            Button {
                MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
                MacQuickLookupPanelController.shared.toggleFloatingPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 11))
                    Text(preferences.quickLookupHotkey.badgeLabel)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                }
            }
            .buttonStyle(VocaSecondaryButtonStyle())
            .help("Mở bảng tra từ nổi toàn hệ thống")

            Spacer()

            if session.isSignedIn {
                Button {
                    Task {
                        await refreshDataIfNeeded(force: true)
                        showToast(icon: "checkmark.circle.fill", message: "Đã đồng bộ dữ liệu")
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Đồng bộ lại dữ liệu")
            }

            Menu {
                Toggle(
                    "Hiện số thẻ đến hạn trên Menu Bar",
                    isOn: Binding(
                        get: { preferences.menuBarBadgeStyle == .dueCount },
                        set: { preferences.setMenuBarBadgeStyle($0 ? .dueCount : .iconOnly) }
                    )
                )

                Toggle(
                    "Ẩn icon dưới Dock",
                    isOn: Binding(
                        get: { preferences.hideDockIcon },
                        set: { preferences.setHideDockIcon($0) }
                    )
                )

                Toggle(
                    "Khởi động cùng macOS",
                    isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { preferences.setLaunchAtLogin($0) }
                    )
                )

                if preferences.launchAtLogin, preferences.launchAtLoginError != nil {
                    Button("Cấp quyền Mục đăng nhập trong Hệ thống…") {
                        MacSystemIntegrations.openLoginItemsSettings()
                    }
                }

                Divider()

                Button("Bảng phím tắt (⌘/)") {
                    withAnimation(.snappy(duration: 0.18)) {
                        activeMode = .shortcuts
                    }
                }

                Button("Cài đặt Voca… (⌘,)") {
                    openSettingsWindow()
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

                    if preferences.launchAtLogin, preferences.launchAtLoginError != nil {
                        Circle()
                            .fill(VocaDesign.accentAmber)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Tùy chọn nhanh & Cài đặt (⌘,)")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VocaDesign.accentRose)
                    .frame(width: 26, height: 26)
                    .background(VocaDesign.accentRose.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Thoát Voca (⌘Q)")
        }
    }

    // MARK: - 8. Hidden Keyboard Shortcuts Engine

    private var hiddenKeyboardShortcuts: some View {
        ZStack {
            // Focus search (`⌘F`)
            Button("") {
                activeMode = .overview
                peekedItemID = nil
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)

            // Toggle shortcut legend (`⌘/`)
            Button("") {
                withAnimation(.snappy(duration: 0.18)) {
                    activeMode = (activeMode == .shortcuts) ? .overview : .shortcuts
                }
            }
            .keyboardShortcut("/", modifiers: .command)

            // Toggle AI target language (`⌘L`)
            Button("") {
                withAnimation(.snappy(duration: 0.16)) {
                    aiCreateLanguage = (aiCreateLanguage == .english) ? .chinese : .english
                }
            }
            .keyboardShortcut("l", modifiers: .command)

            // Start / Restart Mini Review (`⌘R`)
            Button("") {
                if session.isSignedIn {
                    startMiniReview()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            // Shuffle Word of the Day (`⇧⌘R`)
            Button("") {
                withAnimation(.snappy(duration: 0.2)) {
                    spotlightOffset += 1
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            // Pronounce active word/card (`⌘P`)
            Button("") {
                pronounceActiveTarget()
            }
            .keyboardShortcut("p", modifiers: .command)

            // Favorite active word (`⌘D`)
            Button("") {
                if let target = activeVocabularyTarget {
                    toggleFavorite(target)
                }
            }
            .keyboardShortcut("d", modifiers: .command)

            // Copy active word (`⌘C` when not typing in search)
            if peekedItem != nil || (trimmedQuery.isEmpty && activeMode == .overview) {
                Button("") {
                    if let target = activeVocabularyTarget {
                        copyItem(target)
                    }
                }
                .keyboardShortcut("c", modifiers: .command)
            }

            // Open active word in full Voca (`⌘↩`)
            Button("") {
                if let target = activeVocabularyTarget {
                    openVocabularyItem(target)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)

            // Force AI create when search has partial matches (`⇧↩`)
            if !trimmedQuery.isEmpty && !hasExactMatch {
                Button("") {
                    createQuickWord()
                }
                .keyboardShortcut(.return, modifiers: .shift)
            }

            // Open Voca Main Window (`⌘O`) & Quick Destinations (`⌘1…6`)
            Button("") {
                activateMainWindow(destination: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            ForEach(Array(MacDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                Button("") {
                    activateMainWindow(destination: destination)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(index + 1)")),
                    modifiers: .command
                )
            }

            // Add Word (`⌘N`) & Import/OCR (`⇧⌘I`) & Settings (`⌘,`) & Quit (`⌘Q`)
            Button("") {
                activateMainWindow(destination: .vocabulary)
                router.requestAddWord()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("") {
                activateMainWindow(destination: .vocabulary)
                router.requestImportExport(mode: .importWords)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("") {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)

            // Search arrow navigation (only when search list is visible)
            if activeMode == .overview && peekedItem == nil && !matchedItems.isEmpty {
                Button("") {
                    moveSearchSelection(offset: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                Button("") {
                    moveSearchSelection(offset: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [])
            }

            // Mini Review unmodified shortcuts (safe because no TextField is mounted in `.miniReview`)
            if activeMode == .miniReview {
                if miniPhase == .prompt {
                    Button("") {
                        revealMiniCard()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                } else if miniPhase == .revealed {
                    ForEach(MacReviewGrade.allCases) { grade in
                        Button("") {
                            submitMiniGrade(grade)
                        }
                        .keyboardShortcut(grade.keyboardKey, modifiers: [])
                    }
                }

                Button("") {
                    undoLastMiniCard()
                }
                .keyboardShortcut("z", modifiers: .command)
            }

            // Contextual Escape (`Esc`)
            Button("") {
                handleEscape()
            }
            .keyboardShortcut(.cancelAction)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers & State Actions

    private func glassCardSurface(tint: Color? = nil, tintOpacity: Double = 0.05) -> some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                tint != nil
                    ? tint!.opacity(tintOpacity)
                    : Color.primary.opacity(0.045)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        tint != nil
                            ? tint!.opacity(0.22)
                            : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }

    private func miniIconAction(
        icon: String,
        tint: Color,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func miniToastView(_ info: (icon: String, message: String, tint: Color)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: info.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(info.tint)
            Text(info.message)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(info.tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }

    private func showToast(
        icon: String,
        message: String,
        tint: Color = VocaDesign.brandGreen
    ) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            toast = (icon: icon, message: message, tint: tint)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if toast?.message == message {
                withAnimation(.easeOut(duration: 0.18)) {
                    toast = nil
                }
            }
        }
    }

    private var trimmedQuery: String {
        quickQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var peekedItem: MacVocabularyItem? {
        guard let peekedItemID else { return nil }
        return vocabulary.items.first(where: { $0.id == peekedItemID })
    }

    private var matchedItems: [MacVocabularyItem] {
        let q = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !q.isEmpty else { return [] }
        return vocabulary.items
            .filter { item in
                item.term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                    || item.displayMeaningVi.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                    || (item.pronunciation ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
            }
            .sorted { left, right in
                let leftExact = left.term.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                let rightExact = right.term.compare(trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                if leftExact != rightExact { return leftExact }
                return left.term.localizedCaseInsensitiveCompare(right.term) == .orderedAscending
            }
    }

    private var hasExactMatch: Bool {
        let target = trimmedQuery.lowercased()
        guard !target.isEmpty else { return true }
        return vocabulary.items.contains {
            $0.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }

    private var spotlightPool: [MacVocabularyItem] {
        let prioritized = vocabulary.items.sorted { left, right in
            if left.isDue != right.isDue { return left.isDue }
            let leftLearning = left.normalizedLevel == "learning"
            let rightLearning = right.normalizedLevel == "learning"
            if leftLearning != rightLearning { return leftLearning }
            if left.isFavorite != right.isFavorite { return left.isFavorite }
            return left.term < right.term
        }
        return prioritized
    }

    private var spotlightWord: MacVocabularyItem? {
        let pool = spotlightPool
        guard !pool.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = (dayOfYear + spotlightOffset) % pool.count
        return pool[index]
    }

    private var activeVocabularyTarget: MacVocabularyItem? {
        if let peekedItem {
            return peekedItem
        }
        if !trimmedQuery.isEmpty {
            let displayed = Array(matchedItems.prefix(5))
            if let selectedResultID,
               let found = displayed.first(where: { $0.id == selectedResultID }) {
                return found
            }
            return displayed.first
        }
        return spotlightWord
    }

    private var activeClipboardSuggestion: String? {
        guard let candidate = clipboardCandidate,
              candidate != dismissedClipboardCandidate,
              candidate.caseInsensitiveCompare(trimmedQuery) != .orderedSame
        else {
            return nil
        }
        return candidate
    }

    private func inspectClipboardCandidate() {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.count <= 36,
              !raw.contains("\n"),
              raw.rangeOfCharacter(from: .letters) != nil
        else {
            clipboardCandidate = nil
            return
        }
        clipboardCandidate = raw
    }

    private func configureGlobalIntegrations() {
        MacQuickLookupPanelController.shared.configure(
            router: router,
            vocabulary: vocabulary,
            speech: speech,
            preferences: preferences,
            openMainWorkspace: {
                openWindow(id: "main-workspace")
            }
        )
    }

    private func refreshDataIfNeeded(force: Bool) async {
        async let todayTask: Void = (force || today.loadState == .idle)
            ? today.load(dailyGoal: preferences.dailyGoal)
            : ()
        async let reviewTask: Void = (force || review.loadState == .idle)
            ? review.load()
            : ()
        async let vocabTask: Void = (force || vocabulary.loadState == .idle)
            ? vocabulary.load()
            : ()
        _ = await (todayTask, reviewTask, vocabTask)
    }

    private func moveSearchSelection(offset: Int) {
        let displayed = Array(matchedItems.prefix(5))
        guard !displayed.isEmpty else { return }
        if let current = selectedResultID,
           let idx = displayed.firstIndex(where: { $0.id == current }) {
            let next = min(max(idx + offset, 0), displayed.count - 1)
            selectedResultID = displayed[next].id
        } else {
            selectedResultID = displayed.first?.id
        }
    }

    private func handleSearchSubmit() {
        let displayed = Array(matchedItems.prefix(5))
        if displayed.isEmpty && !trimmedQuery.isEmpty {
            createQuickWord()
        } else if let selectedResultID,
                  let found = displayed.first(where: { $0.id == selectedResultID }) {
            withAnimation(.snappy(duration: 0.18)) {
                peekedItemID = found.id
            }
        } else if let first = displayed.first {
            withAnimation(.snappy(duration: 0.18)) {
                peekedItemID = first.id
            }
        }
    }

    private func createQuickWord() {
        let word = trimmedQuery
        guard !word.isEmpty, !isCreatingInline else { return }
        isCreatingInline = true
        let language: MacVocabularyItem.Language = VocaDesign.containsHanCharacters(word)
            ? .chinese
            : aiCreateLanguage

        Task {
            do {
                let created = try await vocabulary.create(word: word, language: language)
                isCreatingInline = false
                quickQuery = created.term
                withAnimation(.snappy(duration: 0.18)) {
                    peekedItemID = created.id
                }
                showToast(icon: "sparkles", message: "Đã tạo “\(created.term)” ✓")
            } catch {
                isCreatingInline = false
                showToast(
                    icon: "exclamationmark.triangle.fill",
                    message: error.localizedDescription,
                    tint: VocaDesign.accentRose
                )
            }
        }
    }

    private func startMiniReview() {
        let dueCards = Array(review.cards.prefix(5))
        if !dueCards.isEmpty {
            miniQueue = dueCards
            isMiniPracticeFallback = false
        } else {
            let fallback = Array(spotlightPool.prefix(5)).map { item in
                MacReviewCard(
                    id: item.id,
                    prompt: item.term,
                    pronunciation: item.pronunciation,
                    meaning: item.displayMeaningVi,
                    example: item.examples.first,
                    language: item.language
                )
            }
            guard !fallback.isEmpty else { return }
            miniQueue = fallback
            isMiniPracticeFallback = true
        }

        miniIndex = 0
        miniHistory = []
        miniPhase = .prompt
        isSearchFocused = false
        withAnimation(.snappy(duration: 0.2)) {
            activeMode = .miniReview
        }
        if preferences.playAudioAutomatically, let first = miniQueue.first {
            speech.speak(first.prompt, language: first.language)
        }
    }

    private func revealMiniCard() {
        guard miniPhase == .prompt else { return }
        withAnimation(.snappy(duration: 0.18)) {
            miniPhase = .revealed
        }
    }

    private func submitMiniGrade(_ grade: MacReviewGrade) {
        guard miniPhase == .revealed, let card = currentMiniCard else { return }
        miniHistory.append(GradedMiniCard(card: card, grade: grade))

        if !isMiniPracticeFallback {
            Task {
                let ok = await review.submit(cardID: card.id, grade: grade)
                if ok {
                    today.recordCompletedReview()
                    vocabulary.markReviewed(cardID: card.id)
                }
            }
        }

        if miniIndex + 1 < miniQueue.count {
            miniIndex += 1
            miniPhase = .prompt
            if preferences.playAudioAutomatically, let next = currentMiniCard {
                speech.speak(next.prompt, language: next.language)
            }
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                miniPhase = .completed
            }
        }
    }

    private func undoLastMiniCard() {
        guard let last = miniHistory.popLast(), miniIndex > 0 else { return }
        if !isMiniPracticeFallback {
            review.restoreCard(last.card, at: 0)
        }
        withAnimation(.snappy(duration: 0.18)) {
            miniIndex = max(miniIndex - 1, 0)
            miniPhase = .revealed
        }
    }

    private func pronounceActiveTarget() {
        if activeMode == .miniReview, let card = currentMiniCard {
            speech.toggle(card.prompt, language: card.language)
        } else if let item = activeVocabularyTarget {
            speech.toggle(item.term, language: item.language)
        }
    }

    private func toggleFavorite(_ item: MacVocabularyItem) {
        let willFavorite = !item.isFavorite
        vocabulary.toggleFavorite(item.id)
        showToast(
            icon: willFavorite ? "star.fill" : "star.slash",
            message: willFavorite ? "Đã lưu Yêu thích ★" : "Đã bỏ Yêu thích",
            tint: willFavorite ? VocaDesign.accentAmber : .secondary
        )
    }

    private func copyItem(_ item: MacVocabularyItem) {
        var parts = [item.term]
        if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
            parts.append(pronunciation)
        }
        parts.append("— \(item.displayMeaningVi)")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: " "), forType: .string)
        showToast(icon: "doc.on.doc.fill", message: "Đã sao chép “\(item.term)”")
    }

    private func handleEscape() {
        if activeMode == .shortcuts || activeMode == .miniReview {
            withAnimation(.snappy(duration: 0.18)) {
                activeMode = .overview
            }
        } else if peekedItemID != nil {
            withAnimation(.snappy(duration: 0.18)) {
                peekedItemID = nil
            }
        } else if !quickQuery.isEmpty {
            quickQuery = ""
        } else {
            MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
        }
    }

    private func openVocabularyItem(_ item: MacVocabularyItem) {
        activateMainWindow(destination: .vocabulary)
        router.open(.vocabularyWord(id: item.id))
    }

    private func openReviewFocusWindow() {
        MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
        openWindow(id: "review-focus")
        MacSystemIntegrations.bringMainWindowsToFront()
    }

    private func openSettingsWindow() {
        MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func activateMainWindow(destination: MacDestination?) {
        MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()
        if let destination {
            router.select(destination)
        }
        openWindow(id: "main-workspace")
        MacSystemIntegrations.bringMainWindowsToFront()
    }
}
