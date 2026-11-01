import AppKit
import SwiftUI

struct MacMenuBarView: View {
    @Environment(MacAppRouter.self) private var router
    @Environment(MacSessionStore.self) private var session
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacTodayStore.self) private var today
    @Environment(MacReviewStore.self) private var review
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @ViewState private var quickQuery = ""
    @ViewState private var isCreatingInline = false
    @ViewState private var inlineFeedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !session.isSignedIn {
                signedOutContent
            } else {
                quickSearchField

                if !trimmedQuery.isEmpty {
                    searchResultsSection
                } else {
                    dueSummaryCard
                    if let word = wordOfTheDay {
                        wordOfTheDayCard(word)
                    }
                }

                systemModeRow
            }

            Divider()
                .opacity(0.6)

            footer
        }
        .padding(14)
        .frame(width: 348)
        .onAppear {
            MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: preferences.hideDockIcon)
        }
    }

    // MARK: - 1. Clean Header

    private var header: some View {
        HStack(spacing: 10) {
            VocaBrandMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Voca Dictionary")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Text("\(vocabulary.items.count) từ vựng đã lưu")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if today.snapshot.streakDays > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(today.snapshot.streakDays)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }

            if session.isSignedIn {
                HStack(spacing: 5) {
                    Circle()
                        .fill(
                            vocabulary.pendingMutationCount > 0
                                ? VocaDesign.accentAmber
                                : VocaDesign.brandGreen
                        )
                        .frame(width: 6.5, height: 6.5)

                    Text(
                        vocabulary.pendingMutationCount > 0
                            ? "\(vocabulary.pendingMutationCount) chờ"
                            : "Synced"
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05), in: Capsule())
            }
        }
    }

    // MARK: - 2. Signed Out State

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Đăng nhập để đồng bộ từ vựng, tra từ nhanh và ôn tập ngay từ thanh Menu Bar.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                activateMainWindow(destination: .today)
            } label: {
                Label("Mở Voca & Đăng nhập", systemImage: "arrow.up.forward.app.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - 3. Instant Search & Quick Add Bar

    private var quickSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Tra nhanh hoặc gõ từ mới để thêm…", text: $quickQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .onSubmit {
                    if matchedItems.isEmpty && !trimmedQuery.isEmpty {
                        createQuickWord()
                    } else if let first = matchedItems.first {
                        openVocabularyItem(first)
                    }
                }

            if !quickQuery.isEmpty {
                Button {
                    quickQuery = ""
                    inlineFeedback = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !matchedItems.isEmpty {
                ForEach(matchedItems.prefix(4)) { item in
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(item.term)
                                    .font(
                                        item.language == .chinese
                                            ? VocaDesign.hanziFont(size: 18, weight: .bold)
                                            : .system(size: 13, weight: .bold)
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
                            }

                            Text(item.displayMeaningVi)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

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
                            .background(VocaDesign.brandGreen.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture {
                        openVocabularyItem(item)
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
                                : "Thêm từ “\(trimmedQuery)” bằng AI"
                        )
                        .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("↩")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .opacity(0.8)
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                .disabled(isCreatingInline)
            }

            if let inlineFeedback {
                Text(inlineFeedback)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VocaDesign.brandGreen)
            }
        }
    }

    // MARK: - 4. Due Summary & Word of the Day Cards

    private var dueSummaryCard: some View {
        let dueCount = max(today.snapshot.dueCount, review.cards.count)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dueCount > 0 ? "\(dueCount) thẻ cần ôn tập" : "Đã hoàn thành ôn tập ✓")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(dueCount > 0 ? .primary : VocaDesign.brandGreen)

                    Text("Mục tiêu ngày: \(today.snapshot.completedGoalCount)/\(today.snapshot.dailyGoal) hoạt động")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if dueCount > 0 {
                    Button {
                        activateMainWindow(destination: .review)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Ôn tập")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                } else {
                    Button {
                        activateMainWindow(destination: .vocabulary)
                    } label: {
                        Text("Từ điển")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                }
            }

            ProgressView(value: min(max(today.snapshot.goalProgress, 0), 1))
                .tint(VocaDesign.brandGreen)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func wordOfTheDayCard(_ item: MacVocabularyItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TỪ VỰNG HÔM NAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

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
                }
                .buttonStyle(.plain)
                .help("Phát âm \(item.term)")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.term)
                    .font(
                        item.language == .chinese
                            ? VocaDesign.hanziFont(size: 22, weight: .bold)
                            : .system(size: 15, weight: .bold, design: .rounded)
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            openVocabularyItem(item)
        }
    }

    // MARK: - 5. Quick System Mode Toggles (Dock Icon & Launch at Login)

    private var systemModeRow: some View {
        HStack(spacing: 12) {
            Toggle(
                isOn: Binding(
                    get: { preferences.hideDockIcon },
                    set: { preferences.setHideDockIcon($0) }
                )
            ) {
                Text("Ẩn icon Dock")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .toggleStyle(.checkbox)

            Spacer()

            HStack(spacing: 4) {
                Toggle(
                    isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { preferences.setLaunchAtLogin($0) }
                    )
                ) {
                    Text("Mở cùng macOS")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .toggleStyle(.checkbox)

                if preferences.launchAtLogin, preferences.launchAtLoginError != nil {
                    Button {
                        MacSystemIntegrations.openLoginItemsSettings()
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(VocaDesign.accentAmber)
                    }
                    .buttonStyle(.plain)
                    .help("Chưa được kích hoạt mở cùng macOS (Nhấn để mở Cài đặt Hệ thống > Mục đăng nhập)")
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    // MARK: - 6. Footer Actions

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                activateMainWindow(destination: .vocabulary)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Mở Voca")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(VocaPrimaryButtonStyle())

            Button {
                MacQuickLookupPanelController.shared.toggleFloatingPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 11))
                    Text("⌥Space")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
            .buttonStyle(VocaSecondaryButtonStyle())
            .help("Mở bảng tra từ nổi (Option + Space)")

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Cài đặt (⌘,)")

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

    // MARK: - Helpers

    private var trimmedQuery: String {
        quickQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchedItems: [MacVocabularyItem] {
        let q = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !q.isEmpty else { return [] }
        return vocabulary.items.filter { item in
            item.term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || item.displayMeaningVi.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
                || (item.pronunciation ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
        }
    }

    private var hasExactMatch: Bool {
        let target = trimmedQuery.lowercased()
        guard !target.isEmpty else { return true }
        return vocabulary.items.contains {
            $0.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }

    private var wordOfTheDay: MacVocabularyItem? {
        let pool = vocabulary.items
        guard !pool.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[dayOfYear % pool.count]
    }

    private func createQuickWord() {
        let word = trimmedQuery
        guard !word.isEmpty, !isCreatingInline else { return }
        isCreatingInline = true
        inlineFeedback = nil
        let language: MacVocabularyItem.Language = VocaDesign.containsHanCharacters(word) ? .chinese : .english

        Task {
            do {
                let created = try await vocabulary.create(word: word, language: language)
                isCreatingInline = false
                inlineFeedback = "Đã tạo “\(created.term)” ✓"
                quickQuery = created.term
            } catch {
                isCreatingInline = false
                inlineFeedback = error.localizedDescription
            }
        }
    }

    private func openVocabularyItem(_ item: MacVocabularyItem) {
        activateMainWindow(destination: .vocabulary)
        router.open(.vocabularyWord(id: item.id))
    }

    private func activateMainWindow(destination: MacDestination?) {
        if let destination {
            router.select(destination)
        }
        openWindow(id: "main-workspace")
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
