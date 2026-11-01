import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacVocabularyItem: Identifiable, Hashable, Sendable {
    enum Language: String, CaseIterable, Sendable {
        case english
        case chinese

        var title: String {
            switch self {
            case .english:
                "English"
            case .chinese:
                "Chinese"
            }
        }

        var webLabel: String {
            switch self {
            case .english:
                "English"
            case .chinese:
                "中文"
            }
        }
    }

    let id: String
    var term: String
    var pronunciation: String?
    var meaning: String
    var language: Language
    var level: String?
    var tags: [String]
    var isFavorite: Bool
    var isDue: Bool
    var examples: [String] = []
    var personalNote: String = ""
    var meaningVi: String? = nil
    var meaningEn: String? = nil
    var partOfSpeech: String? = nil
    var topic: String? = nil
    var useCases: [String] = []
    var memoryTip: String? = nil
    var toeicTrap: String? = nil
    var createdAt: String? = nil

    var displayMeaningVi: String {
        if let meaningVi, !meaningVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return meaningVi
        }
        return meaning
    }

    var normalizedLevel: String {
        let raw = (level ?? "new").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "learning", "known", "mastered":
            return raw
        default:
            return "new"
        }
    }

    static let previewItems: [MacVocabularyItem] = [
        MacVocabularyItem(
            id: "concise",
            term: "concise",
            pronunciation: "/kənˈsaɪs/",
            meaning: "Ngắn gọn, súc tích, truyền tải nhiều thông tin rõ ràng bằng ít từ.",
            language: .english,
            level: "known",
            tags: ["writing", "work"],
            isFavorite: true,
            isDue: true,
            examples: [
                "The report is concise and easy to understand.",
                "Keep your cover letter concise and focused on impact."
            ],
            personalNote: "Use in executive summaries.",
            meaningVi: "Ngắn gọn, súc tích",
            meaningEn: "Giving a lot of information clearly and in a few words; brief but comprehensive.",
            partOfSpeech: "adjective",
            topic: "Business & Communication",
            useCases: [
                "a concise summary / report",
                "write in a clear and concise manner"
            ],
            memoryTip: "Con-CISE giống 'precise' (chính xác) — ngắn gọn và chuẩn xác.",
            toeicTrap: "Dễ nhầm với 'short' (chỉ độ dài vật lý) trong khi 'concise' nhấn mạnh sự cô đọng nội dung.",
            createdAt: "2026-10-24T09:00:00Z"
        ),
        MacVocabularyItem(
            id: "resilient",
            term: "resilient",
            pronunciation: "/rɪˈzɪliənt/",
            meaning: "Kiên cường, có khả năng phục hồi nhanh sau khó khăn.",
            language: .english,
            level: "learning",
            tags: ["personal growth", "psychology"],
            isFavorite: false,
            isDue: true,
            examples: [
                "Children are often remarkably resilient.",
                "We built a resilient distributed architecture."
            ],
            personalNote: "",
            meaningVi: "Kiên cường, đàn hồi, phục hồi nhanh",
            meaningEn: "Able to withstand or recover quickly from difficult conditions.",
            partOfSpeech: "adjective",
            topic: "Psychology & Technology",
            useCases: [
                "resilient economy / supply chain",
                "emotionally resilient"
            ],
            memoryTip: "Re-SILI-ent: bật nảy trở lại (re-salire) như lò xo.",
            toeicTrap: "Danh từ là 'resilience' (thường gặp trong bài đọc IELTS/TOEIC về kinh tế & môi trường).",
            createdAt: "2026-10-23T14:30:00Z"
        ),
        MacVocabularyItem(
            id: "jianjie",
            term: "简洁",
            pronunciation: "jiǎn jié",
            meaning: "Ngắn gọn, cô đọng, súc tích.",
            language: .chinese,
            level: "mastered",
            tags: ["writing", "HSK 5"],
            isFavorite: true,
            isDue: false,
            examples: [
                "这篇文章写得很简洁。 (Zhè piān wénzhāng xiě de hěn jiǎnjié.) - Bài viết này được viết rất ngắn gọn súc tích."
            ],
            personalNote: "",
            meaningVi: "Ngắn gọn, súc tích, giản dị",
            meaningEn: "Concise; succinct; brief and clear.",
            partOfSpeech: "adjective",
            topic: "Writing & Style",
            useCases: [
                "语言简洁 (ngôn ngữ súc tích)",
                "设计简洁 (thiết kế tối giản)"
            ],
            memoryTip: "简 (giản: đơn giản) + 洁 (khiết: sạch gọn) = ngắn gọn súc tích.",
            toeicTrap: nil,
            createdAt: "2026-10-22T10:15:00Z"
        ),
        MacVocabularyItem(
            id: "jianchi",
            term: "坚持",
            pronunciation: "jiān chí",
            meaning: "Kiên trì, bền bỉ theo đuổi đến cùng.",
            language: .chinese,
            level: "learning",
            tags: ["motivation", "HSK 4"],
            isFavorite: false,
            isDue: true,
            examples: [
                "只要坚持，就会看到进步。 (Zhǐyào jiānchí, jiù huì kàndào jìnbù.) - Chỉ cần kiên trì thì sẽ thấy sự tiến bộ."
            ],
            personalNote: "",
            meaningVi: "Kiên trì, giữ vững",
            meaningEn: "To persist in; to insist on; to persevere.",
            partOfSpeech: "verb",
            topic: "Personal Growth",
            useCases: [
                "坚持到底 (kiên trì đến cùng)",
                "坚持锻炼 (kiên trì tập luyện)"
            ],
            memoryTip: "坚 (kiên: cứng cáp) + 持 (trì: nắm giữ) = kiên trì.",
            toeicTrap: nil,
            createdAt: "2026-10-20T08:00:00Z"
        ),
        MacVocabularyItem(
            id: "nuance",
            term: "nuance",
            pronunciation: "/ˈnuːɑːns/",
            meaning: "Sắc thái tinh tế về ngữ nghĩa, biểu cảm hoặc âm thanh.",
            language: .english,
            level: "new",
            tags: ["communication", "IELTS"],
            isFavorite: false,
            isDue: false,
            examples: [
                "She understands the subtle nuances of the language.",
                "Good translators capture every cultural nuance."
            ],
            personalNote: "",
            meaningVi: "Sắc thái tinh tế",
            meaningEn: "A subtle difference in or shade of meaning, expression, or sound.",
            partOfSpeech: "noun",
            topic: "Language & Culture",
            useCases: [
                "subtle nuance",
                "nuances of meaning"
            ],
            memoryTip: "Gốc Pháp 'nuer' (tạo bóng/sắc độ mây).",
            toeicTrap: "Tính từ là 'nuanced' (có chiều sâu, tinh tế — rất ăn điểm trong IELTS Writing).",
            createdAt: "2026-10-18T11:20:00Z"
        )
    ]
}

// MARK: - Main Web-Style Vocabulary Screen

struct MacVocabularyView: View {
    enum LanguageFilter: String, CaseIterable, Identifiable {
        case english
        case chinese

        var id: String { rawValue }

        var title: String {
            switch self {
            case .english:
                "English"
            case .chinese:
                "中文"
            }
        }
    }

    enum CreatedDateFilter: String, CaseIterable, Identifiable {
        case all
        case today
        case yesterday
        case last7Days = "7d"
        case last30Days = "30d"
        case older = "older"
        case none = "none"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                "All dates"
            case .today:
                "Today"
            case .yesterday:
                "Yesterday"
            case .last7Days:
                "Last 7 days"
            case .last30Days:
                "Last 30 days"
            case .older:
                "Older than 30 days"
            case .none:
                "No date"
            }
        }
    }

    enum LevelFilter: String, CaseIterable, Identifiable {
        case all
        case new
        case learning
        case known
        case mastered
        case due
        case favorites

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                "All levels"
            case .new:
                "● New"
            case .learning:
                "● Learning"
            case .known:
                "● Known"
            case .mastered:
                "● Mastered"
            case .due:
                "Due for Review"
            case .favorites:
                "★ Favorites"
            }
        }
    }

    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech

    @ViewState private var selectedItemID: MacVocabularyItem.ID?
    @ViewState private var query = ""
    @ViewState private var languageFilter: LanguageFilter = .english
    @ViewState private var selectedTopic = ""
    @ViewState private var selectedPartOfSpeech = ""
    @ViewState private var selectedCreatedDate: CreatedDateFilter = .all
    @ViewState private var selectedLevel: LevelFilter = .all

    @ViewState private var isAddWordSheetPresented = false
    @ViewState private var isFlashcardsPresented = false
    @ViewState private var isAgentChatOpen = false
    @ViewState private var isConfirmingDelete = false

    @ViewState private var isCreatingInline = false
    @ViewState private var inlineCreateFeedback: String?
    @ViewState private var inlineCreateIsError = false

    @ViewState private var draftPersonalNote = ""
    @ViewState private var newTagText = ""
    @ViewState private var focusedHanziCharacter: String?
    @ViewState private var toastBanner: (icon: String, message: String, tint: Color)?
    @FocusState private var isSearchFocused: Bool

    private let requestedItemID: String?
    private let addWord: (() -> Void)?
    private let onDropTextOrFile: ((String) -> Void)?

    init(
        requestedItemID: String? = nil,
        addWord: (() -> Void)? = nil,
        onDropTextOrFile: ((String) -> Void)? = nil
    ) {
        self.requestedItemID = requestedItemID
        self.addWord = addWord
        self.onDropTextOrFile = onDropTextOrFile
    }

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let isCompactWidth = totalWidth < 740
            let isUltraWide = totalWidth >= 1120
            let previewWidth = min(max(totalWidth * (isAgentChatOpen && isUltraWide ? 0.31 : 0.38), 310), 420)
            let chatWidth = min(max(totalWidth * 0.30, 310), 380)

            ZStack {
                VStack(spacing: 0) {
                    webTopHeaderBar
                    Divider().opacity(0.6)
                    webFilterBar(totalWidth: totalWidth)
                    Divider().opacity(0.6)

                    ZStack(alignment: .trailing) {
                        HStack(spacing: 0) {
                            cardGridSection(isCompact: isCompactWidth)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if let selectedItem, !isCompactWidth {
                                Divider().opacity(0.6)

                                cardPreviewDrawer(for: selectedItem)
                                    .frame(width: previewWidth)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))

                                if isAgentChatOpen && isUltraWide {
                                    Divider().opacity(0.6)

                                    MacWordAgentChatDrawer(
                                        item: selectedItem,
                                        onClose: {
                                            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                                isAgentChatOpen = false
                                            }
                                        }
                                    )
                                    .frame(width: chatWidth)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Slide-over overlay drawers for compact / medium window widths
                        if let selectedItem, isCompactWidth {
                            Color.black.opacity(0.28)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        isAgentChatOpen = false
                                        selectedItemID = nil
                                    }
                                }

                            HStack(spacing: 0) {
                                if isAgentChatOpen {
                                    MacWordAgentChatDrawer(
                                        item: selectedItem,
                                        onClose: {
                                            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                                isAgentChatOpen = false
                                            }
                                        }
                                    )
                                    .frame(width: min(max(totalWidth * 0.86, 300), 420))
                                } else {
                                    cardPreviewDrawer(for: selectedItem)
                                        .frame(width: min(max(totalWidth * 0.86, 300), 420))
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .shadow(color: .black.opacity(0.22), radius: 20, x: -6, y: 0)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else if let selectedItem, !isCompactWidth, isAgentChatOpen, !isUltraWide {
                            Color.black.opacity(0.18)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                        isAgentChatOpen = false
                                    }
                                }

                            MacWordAgentChatDrawer(
                                item: selectedItem,
                                onClose: {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                        isAgentChatOpen = false
                                    }
                                }
                            )
                            .frame(width: min(max(totalWidth * 0.44, 320), 400))
                            .frame(maxHeight: .infinity)
                            .shadow(color: .black.opacity(0.22), radius: 20, x: -6, y: 0)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(VocaDesign.subtleWindowBackground)

                if isFlashcardsPresented {
                    MacFlashcardDeckOverlay(
                        items: visibleItems.isEmpty ? languageFilteredItems : visibleItems,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFlashcardsPresented = false
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }

                if let focusedHanziCharacter {
                    MacHanziFocusOverlay(
                        word: focusedHanziCharacter,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                self.focusedHanziCharacter = nil
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(25)
                }

                // Floating Toast HUD Banner
                if let toastBanner {
                    VStack {
                        Spacer()
                        VocaToastBanner(
                            icon: toastBanner.icon,
                            message: toastBanner.message,
                            tint: toastBanner.tint
                        )
                        .padding(.bottom, 22)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
                }

                // Power-User Hidden Keyboard Shortcuts
                hiddenVocabularyShortcuts
            }
        }
        .navigationTitle("Voca Dictionary")
        .sheet(isPresented: $isAddWordSheetPresented) {
            MacAddWordSheet(
                initialWord: canCreateFromResults ? trimmedQuery : "",
                initialLanguage: targetLanguageForInlineCreate
            ) { created in
                selectedItemID = created.id
            }
        }
        .onDrop(
            of: [.fileURL, .plainText],
            isTargeted: nil
        ) { providers in
            handleDroppedProviders(providers)
        }
        .onAppear {
            applyRequestedSelection()
            syncDraftNote()
        }
        .task {
            await vocabulary.load()
            applyRequestedSelection()
            syncDraftNote()
        }
        .onChange(of: requestedItemID) { _, _ in
            applyRequestedSelection()
        }
        .onChange(of: selectedItemID) { _, _ in
            isConfirmingDelete = false
            syncDraftNote()
        }
        .onChange(of: vocabulary.items) { _, _ in
            applyRequestedSelection()
        }
    }

    // MARK: - 1. Web Top Header (`list-heading`)

    private var webTopHeaderTitleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Text("Voca Dictionary")
                    .font(.system(size: 21, weight: .bold, design: .rounded))

                if vocabulary.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Text("\(languageFilteredItems.count) cards · \(visibleItems.count) shown")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                if vocabulary.pendingMutationCount > 0 {
                    Text("· \(vocabulary.pendingMutationCount) waiting to sync")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VocaDesign.accentAmber)
                }
            }
        }
    }

    private var webTopHeaderControlsBlock: some View {
        HStack(spacing: 8) {
            // Language Switcher (`All | English | 中文`)
            HStack(spacing: 3) {
                ForEach(LanguageFilter.allCases) { option in
                    let isSelected = languageFilter == option
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            languageFilter = option
                            selectedTopic = ""
                            selectedPartOfSpeech = ""
                        }
                    } label: {
                        Text(option.title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? VocaDesign.brandGreen : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Flashcards Deck Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFlashcardsPresented = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Flashcards")
                        .font(.system(size: 12.5, weight: .semibold))
                }
            }
            .buttonStyle(VocaSecondaryButtonStyle())
            .disabled(languageFilteredItems.isEmpty)
            .keyboardShortcut("l", modifiers: .command)
            .help("Open Flashcard Deck (⌘L)")

            // Add Word (+) Button
            Button {
                isAddWordSheetPresented = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Word")
                        .font(.system(size: 12.5, weight: .semibold))
                }
            }
            .buttonStyle(VocaPrimaryButtonStyle())
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a new word with AI (⌘N)")

            // Refresh Button
            Button {
                Task {
                    await vocabulary.retry()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(vocabulary.isLoading)
            .help("Refresh vocabulary from server")
        }
    }

    private var webTopHeaderBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                webTopHeaderTitleBlock
                Spacer(minLength: 12)
                webTopHeaderControlsBlock
            }

            VStack(alignment: .leading, spacing: 10) {
                webTopHeaderTitleBlock
                HStack {
                    webTopHeaderControlsBlock
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
    }

    // MARK: - 2. Web Utility Filter Bar (`FilterBar` / `.utility-bar`)

    private var searchInputColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SEARCH")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSearchFocused ? VocaDesign.brandGreen : .secondary)

                TextField("word, meaning, topic, tag...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onSubmit {
                        handleSearchSubmit()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        inlineCreateFeedback = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("⌘↩")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .help("Press Return to create missing word with AI or pronounce matched word")
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 190, maxWidth: .infinity, minHeight: 32, maxHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSearchFocused
                            ? VocaDesign.brandGreen.opacity(0.65)
                            : Color.primary.opacity(0.12),
                        lineWidth: isSearchFocused ? 1.5 : 1
                    )
            )
        }
    }

    @ViewBuilder
    private var filterDropdownsGroup: some View {
        // TOPIC FILTER
        filterMenuColumn(
            label: "TOPIC",
            activeTitle: selectedTopic.isEmpty ? "All topics" : selectedTopic,
            isActive: !selectedTopic.isEmpty
        ) {
            Button("All topics") {
                selectedTopic = ""
            }
            if !availableTopics.isEmpty {
                Divider()
                ForEach(availableTopics, id: \.self) { topic in
                    Button(topic) {
                        selectedTopic = topic
                    }
                }
            }
        }

        // PART OF SPEECH FILTER
        filterMenuColumn(
            label: "PART OF SPEECH",
            activeTitle: selectedPartOfSpeech.isEmpty
                ? "All types"
                : formatPartOfSpeechLabel(selectedPartOfSpeech),
            isActive: !selectedPartOfSpeech.isEmpty
        ) {
            Button("All types") {
                selectedPartOfSpeech = ""
            }
            if !availablePartsOfSpeech.isEmpty {
                Divider()
                ForEach(availablePartsOfSpeech, id: \.self) { pos in
                    Button(formatPartOfSpeechLabel(pos)) {
                        selectedPartOfSpeech = pos
                    }
                }
            }
        }

        // CREATED DATE FILTER
        filterMenuColumn(
            label: "CREATED DATE",
            activeTitle: selectedCreatedDate.title,
            isActive: selectedCreatedDate != .all
        ) {
            ForEach(CreatedDateFilter.allCases) { dateFilter in
                Button(dateFilter.title) {
                    selectedCreatedDate = dateFilter
                }
            }
        }

        // LEVEL FILTER
        filterMenuColumn(
            label: "LEVEL",
            activeTitle: selectedLevel.title,
            isActive: selectedLevel != .all
        ) {
            ForEach(LevelFilter.allCases) { levelOption in
                Button(levelOption.title) {
                    selectedLevel = levelOption
                }
            }
        }

        // CLEAR BUTTON
        if hasActiveFilters {
            VStack(alignment: .leading, spacing: 4) {
                Text(" ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Button {
                    clearAllFilters()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Clear")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func webFilterBar(totalWidth: CGFloat) -> some View {
        Group {
            if totalWidth >= 860 {
                HStack(alignment: .bottom, spacing: 10) {
                    searchInputColumn
                    filterDropdownsGroup
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    searchInputColumn

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 132, maximum: 220), spacing: 8)
                        ],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        filterDropdownsGroup
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.38))
    }

    private func filterMenuColumn<MenuContent: View>(
        label: String,
        activeTitle: String,
        isActive: Bool,
        @ViewBuilder content: () -> MenuContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    Text(activeTitle)
                        .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? VocaDesign.brandGreen : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .frame(minWidth: 124, maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isActive
                                ? VocaDesign.brandGreen.opacity(0.10)
                                : Color(nsColor: .textBackgroundColor)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isActive
                                ? VocaDesign.brandGreen.opacity(0.45)
                                : Color.primary.opacity(0.12),
                            lineWidth: 1
                        )
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - 3. Multi-Column Card Grid & Inline AI Create (`card-list` / `card-row`)

    private func cardGridSection(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            // Inline AI creation banner when search query has no exact card match
            if canCreateFromResults || isCreatingInline || inlineCreateFeedback != nil {
                inlineCreateBanner
                    .padding(.horizontal, isCompact ? 14 : 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }

            if vocabulary.isLoading && vocabulary.items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading vocabulary from server…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = vocabulary.errorMessage,
                      vocabulary.items.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(VocaDesign.accentAmber)

                    Text("Unable to Load Vocabulary")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)

                    Button("Try Again") {
                        Task {
                            await vocabulary.retry()
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                emptyVocabularyState
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(
                                        minimum: isCompact ? 235 : 270,
                                        maximum: 480
                                    ),
                                    spacing: 12
                                )
                            ],
                            spacing: 12
                        ) {
                            ForEach(visibleItems) { item in
                                MacWebVocabularyCard(
                                    item: item,
                                    isSelected: selectedItemID == item.id,
                                    isSpeaking: speech.isSpeaking && speech.speakingText == item.term,
                                    onSelect: {
                                        withAnimation(.snappy(duration: 0.18)) {
                                            if selectedItemID == item.id {
                                                selectedItemID = nil
                                                isAgentChatOpen = false
                                            } else {
                                                selectedItemID = item.id
                                            }
                                        }
                                    },
                                    onSpeak: {
                                        speech.toggle(item.term, language: item.language)
                                    },
                                    onToggleFavorite: {
                                        toggleFavorite(item.id)
                                    },
                                    onCopy: {
                                        copyWordToClipboard(item)
                                    },
                                    onDelete: {
                                        delete(item.id)
                                    },
                                    onSelectLevel: { level in
                                        Task {
                                            await vocabulary.updateLevel(level, for: item.id)
                                            showToast(
                                                icon: "checkmark.circle.fill",
                                                message: "Đã cập nhật “\(item.term)” → \(level.capitalized)",
                                                tint: VocaDesign.brandGreen
                                            )
                                        }
                                    },
                                    onFocusHanzi: { character in
                                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                            focusedHanziCharacter = character
                                        }
                                    }
                                )
                                .equatable()
                                .id(item.id)
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: selectedItemID) { _, newID in
                        if let newID {
                            withAnimation(.snappy(duration: 0.2)) {
                                scrollProxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage = vocabulary.errorMessage,
               !vocabulary.items.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(VocaDesign.accentAmber)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Retry") {
                        Task {
                            await vocabulary.retry()
                        }
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }

    private var inlineCreateBanner: some View {
        HStack(spacing: 14) {
            VocaIconBadge(
                systemImage: isCreatingInline ? "hourglass" : "sparkles",
                tint: inlineCreateIsError ? VocaDesign.accentRose : VocaDesign.brandGreen,
                size: 34
            )

            VStack(alignment: .leading, spacing: 2) {
                if isCreatingInline {
                    Text("Generating “\(trimmedQuery)” with AI…")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Building phonetics, Vietnamese/English meanings, examples, and memory tips.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                } else if let inlineCreateFeedback {
                    Text(inlineCreateFeedback)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(inlineCreateIsError ? VocaDesign.accentRose : VocaDesign.brandGreen)
                } else {
                    Text(
                        visibleItems.isEmpty
                            ? "No exact card for “\(trimmedQuery)” in your dictionary."
                            : "Found related vocabulary, but no exact card for “\(trimmedQuery)”."
                    )
                    .font(.system(size: 13, weight: .semibold))

                    Text("Create a rich AI vocabulary card (\(targetLanguageForInlineCreate.webLabel)) in one click or press ⌘↩.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isCreatingInline {
                ProgressView()
                    .controlSize(.small)
            } else if canCreateFromResults {
                Button {
                    createMissingCardInline()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("Create “\(trimmedQuery)”")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VocaDesign.brandGreen.opacity(0.32), lineWidth: 1)
        )
    }

    private var emptyVocabularyState: some View {
        VStack(spacing: 16) {
            VocaIconBadge(
                systemImage: query.isEmpty ? "books.vertical.fill" : "sparkles",
                tint: VocaDesign.brandGreen,
                size: 52
            )

            Text(query.isEmpty ? "No matching cards" : "No card for “\(trimmedQuery)”")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(
                query.isEmpty
                    ? "Try adjusting your filters or add a new English / Chinese word with AI."
                    : "Create “\(trimmedQuery)” right now with AI to generate meanings, IPA/Pinyin, and examples."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)

            HStack(spacing: 10) {
                if canCreateFromResults {
                    Button {
                        createMissingCardInline()
                    } label: {
                        HStack(spacing: 6) {
                            if isCreatingInline {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isCreatingInline ? "Creating “\(trimmedQuery)”…" : "Create “\(trimmedQuery)”")
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .disabled(isCreatingInline)
                } else {
                    Button {
                        isAddWordSheetPresented = true
                    } label: {
                        Label("Add Word with AI", systemImage: "plus")
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                }

                if hasActiveFilters {
                    Button("Clear Filters") {
                        clearAllFilters()
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - 4. Web-Style Right `CardPreview` Drawer

    private func cardPreviewDrawer(for item: MacVocabularyItem) -> some View {
        VStack(spacing: 0) {
            // Sticky Preview Header (`preview-header`)
            VStack(alignment: .leading, spacing: 10) {
                // Top Eyebrow + Action Icons
                HStack(alignment: .center) {
                    Text("PREVIEW")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if isConfirmingDelete {
                        HStack(spacing: 6) {
                            Text("Xóa từ này?")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(VocaDesign.accentRose)

                            Button("Xóa") {
                                isConfirmingDelete = false
                                delete(item.id)
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(VocaDesign.accentRose, in: RoundedRectangle(cornerRadius: 6))
                            .buttonStyle(.plain)

                            Button("Hủy") {
                                isConfirmingDelete = false
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 6) {
                            // Copy Word Button
                            previewIconButton(
                                icon: "doc.on.doc",
                                tint: .secondary,
                                isActive: false,
                                tooltip: "Sao chép từ vựng & nghĩa (⌘C)"
                            ) {
                                copyWordToClipboard(item)
                            }

                            // Favorite Button
                            previewIconButton(
                                icon: item.isFavorite ? "star.fill" : "star",
                                tint: item.isFavorite ? VocaDesign.accentAmber : .secondary,
                                isActive: item.isFavorite,
                                tooltip: item.isFavorite ? "Bỏ yêu thích (⌘D)" : "Đánh dấu yêu thích (⌘D)"
                            ) {
                                toggleFavorite(item.id)
                            }

                            // Delete Button
                            previewIconButton(
                                icon: "trash",
                                tint: VocaDesign.accentRose,
                                isActive: false,
                                tooltip: "Xóa từ vựng"
                            ) {
                                isConfirmingDelete = true
                            }

                            // Ask AI Agent Button (`Sparkles`)
                            previewIconButton(
                                icon: "sparkles",
                                tint: VocaDesign.brandGreen,
                                isActive: isAgentChatOpen,
                                tooltip: "Hỏi AI Agent về từ này (⌘I)"
                            ) {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                    isAgentChatOpen.toggle()
                                }
                            }

                            // Close Preview Button (`X`)
                            previewIconButton(
                                icon: "xmark",
                                tint: .secondary,
                                isActive: false,
                                tooltip: "Đóng Preview (ESC)"
                            ) {
                                withAnimation(.snappy(duration: 0.18)) {
                                    isAgentChatOpen = false
                                    selectedItemID = nil
                                }
                            }
                        }
                    }
                }

                // Word Title + Speak Button (Chinese replaces plain text directly with interactive Hanzi Tianzige boxes)
                HStack(alignment: .center, spacing: 10) {
                    if item.language == .chinese, VocaDesign.containsHanCharacters(item.term) {
                        MacHanziWritingGuide(
                            word: item.term,
                            compact: false,
                            displayOnly: false,
                            onCharacterFocus: { character in
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                    focusedHanziCharacter = character
                                }
                            }
                        )
                    } else {
                        Text(item.term)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .textSelection(.enabled)
                    }

                    Button {
                        speech.toggle(item.term, language: item.language)
                    } label: {
                        Image(
                            systemName: speech.isSpeaking && speech.speakingText == item.term
                                ? "stop.fill"
                                : "speaker.wave.2.fill"
                        )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VocaDesign.brandGreen)
                        .frame(width: 30, height: 30)
                        .background(
                            VocaDesign.brandGreen.opacity(0.14),
                            in: Circle()
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Pronounce \(item.term)")
                }

                // POS · Topic subtitle (`preview-sub`)
                HStack(spacing: 6) {
                    if let pos = item.partOfSpeech, !pos.isEmpty {
                        MacPOSBadge(partOfSpeech: pos)
                    } else {
                        MacPOSBadge(partOfSpeech: "unknown")
                    }

                    if let topic = item.topic, !topic.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(topic)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                // Phonetic / Pinyin (`preview-ipa` / `hanzi-preview-pinyin`)
                if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(
                            .system(
                                size: item.language == .chinese ? 15 : 13.5,
                                weight: .medium,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(
                            item.language == .chinese ? VocaDesign.brandGreen : .secondary
                        )
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .textSelection(.enabled)
                }

                // Created Date + Compact Level Selector (`preview-meta`)
                HStack(spacing: 10) {
                    if let formattedDate = formatCreatedDate(item.createdAt) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(formattedDate)
                                .font(.system(size: 11.5, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Level selector menu (`level-select-compact`)
                    Menu {
                        ForEach(["new", "learning", "known", "mastered"], id: \.self) { level in
                            Button {
                                Task {
                                    await vocabulary.updateLevel(level, for: item.id)
                                    showToast(
                                        icon: "checkmark.circle.fill",
                                        message: "Đã cập nhật “\(item.term)” → \(level.capitalized)",
                                        tint: VocaDesign.brandGreen
                                    )
                                }
                            } label: {
                                Label(
                                    level.capitalized,
                                    systemImage: item.normalizedLevel == level ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    } label: {
                        MacLevelBadge(level: item.normalizedLevel, showChevron: true)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                // Tags Pills
                if !item.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                Button {
                                    let updated = item.tags.filter { $0 != tag }
                                    vocabulary.updateTags(updated, for: item.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                    }
                }
            }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))

            Divider().opacity(0.6)

            // Scrollable Preview Sections (`preview-body`)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Nghĩa (Vietnamese)
                    previewSectionCard(title: "NGHĨA (VIETNAMESE)", icon: "text.book.closed.fill", tint: VocaDesign.brandGreen) {
                        Text(item.displayMeaningVi)
                            .font(.system(size: 14.5, weight: .medium))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }

                    // Meaning (English)
                    if let meaningEn = item.meaningEn,
                       !meaningEn.isEmpty,
                       meaningEn != item.displayMeaningVi {
                        previewSectionCard(title: "MEANING (ENGLISH)", icon: "globe", tint: VocaDesign.accentSky) {
                            Text(meaningEn)
                                .font(.system(size: 13.5))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                    }

                    // Examples
                    if !item.examples.isEmpty {
                        previewSectionCard(title: "EXAMPLES", icon: "quote.bubble.fill", tint: VocaDesign.accentIndigo) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(item.examples.enumerated()), id: \.offset) { _, example in
                                    previewExampleRow(example, language: item.language)
                                }
                            }
                        }
                    }

                    // Use Cases (Cách dùng)
                    if !item.useCases.isEmpty {
                        previewSectionCard(title: "CÁCH DÙNG (USE CASES)", icon: "Sparkles", tint: VocaDesign.accentSky) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(item.useCases.enumerated()), id: \.offset) { _, useCase in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(VocaDesign.accentSky)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 6)
                                        Text(useCase)
                                            .font(.system(size: 13))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }

                    // Memory Tip (Mẹo ghi nhớ)
                    if let memoryTip = item.memoryTip, !memoryTip.isEmpty {
                        previewSectionCard(
                            title: "MẸO GHI NHỚ",
                            icon: "lightbulb.fill",
                            tint: VocaDesign.accentAmber,
                            accentBackground: VocaDesign.accentAmber.opacity(0.08)
                        ) {
                            Text(memoryTip)
                                .font(.system(size: 13))
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                    }

                    // Vocabulary Trap (Bẫy từ vựng)
                    if let trap = item.toeicTrap, !trap.isEmpty {
                        previewSectionCard(
                            title: "BẪY TỪ VỰNG",
                            icon: "exclamationmark.triangle.fill",
                            tint: VocaDesign.accentRose,
                            accentBackground: VocaDesign.accentRose.opacity(0.08)
                        ) {
                            Text(trap)
                                .font(.system(size: 13))
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                    }

                    // Add Tag & Personal Note
                    previewSectionCard(title: "TAGS & PERSONAL NOTE", icon: "note.text", tint: .secondary) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                TextField("Add tag…", text: $newTagText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                                    )
                                    .onSubmit {
                                        addTag(to: item)
                                    }

                                Button("Add") {
                                    addTag(to: item)
                                }
                                .buttonStyle(VocaSecondaryButtonStyle())
                                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            TextField(
                                "Write a personal memory cue or usage note…",
                                text: $draftPersonalNote,
                                axis: .vertical
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .lineLimit(2...4)
                            .padding(9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                            )
                            .onSubmit {
                                vocabulary.setPersonalNote(draftPersonalNote, for: item.id)
                            }

                            if draftPersonalNote != item.personalNote {
                                Button("Save Note") {
                                    vocabulary.setPersonalNote(draftPersonalNote, for: item.id)
                                }
                                .buttonStyle(VocaPrimaryButtonStyle())
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func previewIconButton(
        icon: String,
        tint: Color,
        isActive: Bool,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isActive ? tint : tint.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isActive ? tint.opacity(0.16) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isActive ? tint.opacity(0.45) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func previewSectionCard<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        accentBackground: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(accentBackground ?? Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    accentBackground != nil ? tint.opacity(0.28) : Color.primary.opacity(0.07),
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private func previewExampleRow(
        _ rawExample: String,
        language: MacVocabularyItem.Language
    ) -> some View {
        if language == .chinese {
            let parsed = ChineseExample(rawExample)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(parsed.hanzi)
                        .font(VocaDesign.hanziFont(size: 19, weight: .bold))
                        .tracking(0.5)
                        .textSelection(.enabled)
                    if let pinyin = parsed.pinyin {
                        Text(pinyin)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VocaDesign.brandGreen)
                    }
                    if let meaningVi = parsed.meaningVi {
                        Text(meaningVi)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    speech.toggle(parsed.hanzi, language: .chinese)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
        } else {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(VocaDesign.accentIndigo.opacity(0.65))
                    .frame(width: 3)

                Text(rawExample)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineSpacing(2)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    speech.toggle(rawExample, language: .english)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 5. Filtering, Search & Inline Creation Logic

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var languageFilteredItems: [MacVocabularyItem] {
        vocabulary.items.filter { item in
            switch languageFilter {
            case .english:
                return item.language == .english
            case .chinese:
                return item.language == .chinese
            }
        }
    }

    private var availableTopics: [String] {
        let topics = Set(
            languageFilteredItems.compactMap { item -> String? in
                guard let topic = item.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !topic.isEmpty
                else {
                    return nil
                }
                return topic
            }
        )
        return topics.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availablePartsOfSpeech: [String] {
        let posSet = Set(
            languageFilteredItems.compactMap { item -> String? in
                guard let pos = item.partOfSpeech?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      !pos.isEmpty
                else {
                    return nil
                }
                return pos
            }
        )
        return posSet.sorted()
    }

    private var visibleItems: [MacVocabularyItem] {
        let base = languageFilteredItems
        let hasTopic = !selectedTopic.isEmpty
        let hasPOS = !selectedPartOfSpeech.isEmpty
        let targetPOS = selectedPartOfSpeech.lowercased()
        let hasDate = selectedCreatedDate != .all
        let hasLevel = selectedLevel != .all
        let normalizedQuery = query.isEmpty
            ? ""
            : trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let hasQuery = !normalizedQuery.isEmpty

        if !hasTopic && !hasPOS && !hasDate && !hasLevel && !hasQuery {
            return base
        }

        return base.filter { item in
            if hasTopic, item.topic?.caseInsensitiveCompare(selectedTopic) != .orderedSame {
                return false
            }
            if hasPOS, item.partOfSpeech?.lowercased() != targetPOS {
                return false
            }
            if hasLevel, !matchesLevelFilter(item) {
                return false
            }
            if hasDate, !matchesCreatedDate(item) {
                return false
            }
            if hasQuery, !matchesNormalizedQuery(item, normalizedQuery: normalizedQuery) {
                return false
            }
            return true
        }
    }

    private var hasExactCardForQuery: Bool {
        let target = trimmedQuery.lowercased()
        guard !target.isEmpty else { return false }
        let targetSlug = target.replacingOccurrences(of: " ", with: "-")
        return vocabulary.items.contains { item in
            item.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
                || item.id.lowercased() == targetSlug
        }
    }

    private var canCreateFromResults: Bool {
        !trimmedQuery.isEmpty && !hasExactCardForQuery
    }

    private var targetLanguageForInlineCreate: MacVocabularyItem.Language {
        if containsHanCharacters(trimmedQuery) || languageFilter == .chinese {
            return .chinese
        }
        return .english
    }

    private var hasActiveFilters: Bool {
        !query.isEmpty
            || !selectedTopic.isEmpty
            || !selectedPartOfSpeech.isEmpty
            || selectedCreatedDate != .all
            || selectedLevel != .all
    }

    private func clearAllFilters() {
        query = ""
        selectedTopic = ""
        selectedPartOfSpeech = ""
        selectedCreatedDate = .all
        selectedLevel = .all
        inlineCreateFeedback = nil
    }

    private func handleSearchSubmit() {
        if canCreateFromResults {
            createMissingCardInline()
        } else if let selectedItem, visibleItems.contains(where: { $0.id == selectedItem.id }) {
            speech.speak(selectedItem.term, language: selectedItem.language)
        } else if let first = visibleItems.first {
            selectedItemID = first.id
            speech.speak(first.term, language: first.language)
        }
    }

    private func createMissingCardInline() {
        let wordToCreate = trimmedQuery
        guard !wordToCreate.isEmpty, !isCreatingInline else { return }

        isCreatingInline = true
        inlineCreateFeedback = nil
        inlineCreateIsError = false
        let lang = targetLanguageForInlineCreate

        Task {
            do {
                let created = try await vocabulary.create(
                    word: wordToCreate,
                    language: lang
                )
                isCreatingInline = false
                inlineCreateIsError = false
                inlineCreateFeedback = "Created “\(created.term)” with AI."
                selectedItemID = created.id
            } catch {
                isCreatingInline = false
                inlineCreateIsError = true
                inlineCreateFeedback = error.localizedDescription
            }
        }
    }

    private func matchesTopic(_ item: MacVocabularyItem) -> Bool {
        guard !selectedTopic.isEmpty else { return true }
        return item.topic?.caseInsensitiveCompare(selectedTopic) == .orderedSame
    }

    private func matchesPartOfSpeech(_ item: MacVocabularyItem) -> Bool {
        guard !selectedPartOfSpeech.isEmpty else { return true }
        return item.partOfSpeech?.lowercased() == selectedPartOfSpeech.lowercased()
    }

    private func matchesLevelFilter(_ item: MacVocabularyItem) -> Bool {
        switch selectedLevel {
        case .all:
            return true
        case .new:
            return item.normalizedLevel == "new"
        case .learning:
            return item.normalizedLevel == "learning"
        case .known:
            return item.normalizedLevel == "known"
        case .mastered:
            return item.normalizedLevel == "mastered"
        case .due:
            return item.isDue
        case .favorites:
            return item.isFavorite
        }
    }

    private func matchesCreatedDate(_ item: MacVocabularyItem) -> Bool {
        guard selectedCreatedDate != .all else { return true }
        guard let raw = item.createdAt, !raw.isEmpty else {
            return selectedCreatedDate == .none
        }
        if selectedCreatedDate == .none {
            return false
        }
        guard let date = parseCreatedDate(raw) else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfCardDay = calendar.startOfDay(for: date)
        let diffDays = calendar.dateComponents([.day], from: startOfCardDay, to: startOfToday).day ?? 0

        switch selectedCreatedDate {
        case .all, .none:
            return true
        case .today:
            return diffDays == 0
        case .yesterday:
            return diffDays == 1
        case .last7Days:
            return diffDays >= 0 && diffDays < 7
        case .last30Days:
            return diffDays >= 0 && diffDays < 30
        case .older:
            return diffDays >= 30
        }
    }

    private func matchesNormalizedQuery(_ item: MacVocabularyItem, normalizedQuery: String) -> Bool {
        let searchableContent = [
            item.term,
            item.pronunciation ?? "",
            item.displayMeaningVi,
            item.meaningEn ?? "",
            item.meaning,
            item.topic ?? "",
            item.partOfSpeech ?? "",
            item.language.title,
            item.level ?? "",
            item.tags.joined(separator: " "),
            item.personalNote
        ]
        .joined(separator: " ")
        .folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        return searchableContent.contains(normalizedQuery)
    }

    private var selectedItem: MacVocabularyItem? {
        guard let selectedItemID else { return nil }
        return vocabulary.items.first(where: { $0.id == selectedItemID })
    }

    private var hiddenVocabularyShortcuts: some View {
        ZStack {
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("") {
                selectAdjacentCard(offset: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("") {
                selectAdjacentCard(offset: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("") {
                guard !isFlashcardsPresented, let item = selectedItem else { return }
                speech.toggle(item.term, language: item.language)
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(isFlashcardsPresented || selectedItem == nil)

            Button("") {
                if let item = selectedItem {
                    toggleFavorite(item.id)
                }
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("") {
                if selectedItem != nil {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        isAgentChatOpen.toggle()
                    }
                }
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("") {
                if let item = selectedItem {
                    copyWordToClipboard(item)
                }
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("") {
                if isFlashcardsPresented {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFlashcardsPresented = false
                    }
                } else if isAgentChatOpen {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        isAgentChatOpen = false
                    }
                } else if selectedItemID != nil {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedItemID = nil
                    }
                }
            }
            .keyboardShortcut(.cancelAction)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func showToast(icon: String, message: String, tint: Color = VocaDesign.brandGreen) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            toastBanner = (icon: icon, message: message, tint: tint)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastBanner?.message == message {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastBanner = nil
                }
            }
        }
    }

    private func copyWordToClipboard(_ item: MacVocabularyItem) {
        var parts = [item.term]
        if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
            parts.append(pronunciation)
        }
        parts.append("— \(item.displayMeaningVi)")
        let text = parts.joined(separator: " ")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(
            icon: "doc.on.doc.fill",
            message: "Đã sao chép “\(item.term)” vào Clipboard",
            tint: VocaDesign.brandGreen
        )
    }

    private func selectAdjacentCard(offset: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        if let currentID = selectedItemID,
           let index = list.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = min(max(index + offset, 0), list.count - 1)
            withAnimation(.snappy(duration: 0.18)) {
                selectedItemID = list[nextIndex].id
            }
        } else {
            withAnimation(.snappy(duration: 0.18)) {
                selectedItemID = offset >= 0 ? list.first?.id : list.last?.id
            }
        }
    }

    private func toggleFavorite(_ identifier: MacVocabularyItem.ID) {
        let wasFavorite = vocabulary.items.first(where: { $0.id == identifier })?.isFavorite ?? false
        let term = vocabulary.items.first(where: { $0.id == identifier })?.term ?? ""
        vocabulary.toggleFavorite(identifier)
        showToast(
            icon: wasFavorite ? "star.slash" : "star.fill",
            message: wasFavorite
                ? "Đã bỏ yêu thích “\(term)”"
                : "Đã thêm “\(term)” vào Yêu thích ★",
            tint: wasFavorite ? .secondary : VocaDesign.accentAmber
        )
    }

    private func addTag(to item: MacVocabularyItem) {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = item.tags
        if !updated.contains(trimmed) {
            updated.append(trimmed)
            vocabulary.updateTags(updated, for: item.id)
        }
        newTagText = ""
    }

    private func syncDraftNote() {
        draftPersonalNote = selectedItem?.personalNote ?? ""
    }

    private func delete(_ identifier: MacVocabularyItem.ID) {
        if selectedItemID == identifier {
            selectedItemID = visibleItems.first(where: { $0.id != identifier })?.id
        }
        Task {
            await vocabulary.delete(identifier)
        }
    }

    private func applyRequestedSelection() {
        if let requestedItemID,
           let matched = vocabulary.items.first(where: { $0.id == requestedItemID }) {
            languageFilter = matched.language == .chinese ? .chinese : .english
            selectedItemID = requestedItemID
        } else if let selectedItemID,
                  !vocabulary.items.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = nil
        }
    }

    private static let isoFractionDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoBasicDateFormatter = ISO8601DateFormatter()

    private static let shortInputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayCreatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private func parseCreatedDate(_ raw: String) -> Date? {
        if let date = Self.isoFractionDateFormatter.date(from: raw) {
            return date
        }
        if let date = Self.isoBasicDateFormatter.date(from: raw) {
            return date
        }
        return Self.shortInputDateFormatter.date(from: String(raw.prefix(10)))
    }

    private func formatCreatedDate(_ raw: String?) -> String? {
        guard let raw, let date = parseCreatedDate(raw) else { return nil }
        return Self.displayCreatedDateFormatter.string(from: date)
    }

    private func formatPartOfSpeechLabel(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Unknown" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
    }

    private func containsHanCharacters(_ value: String) -> Bool {
        VocaDesign.containsHanCharacters(value)
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, _ in
                let resolvedURL: URL?
                if let urlData = item as? Data {
                    resolvedURL = URL(dataRepresentation: urlData, relativeTo: nil)
                } else {
                    resolvedURL = item as? URL
                }

                guard let fileURL = resolvedURL else { return }
                Task { @MainActor in
                    let text = await MacImportParser.extractTextFromFile(at: fileURL)
                    if !text.isEmpty {
                        onDropTextOrFile?(text)
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(
                forTypeIdentifier: UTType.plainText.identifier,
                options: nil
            ) { item, _ in
                let text = (item as? String)
                    ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                guard let text, !text.isEmpty else { return }
                Task { @MainActor in
                    onDropTextOrFile?(text)
                }
            }
            return true
        }

        return false
    }
}

// MARK: - Web-Style Vocabulary Card (`.card-row`)

private struct MacWebVocabularyCard: View, Equatable {
    let item: MacVocabularyItem
    let isSelected: Bool
    let isSpeaking: Bool
    let onSelect: () -> Void
    let onSpeak: () -> Void
    let onToggleFavorite: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onSelectLevel: (String) -> Void
    var onFocusHanzi: ((String) -> Void)?

    static func == (lhs: MacWebVocabularyCard, rhs: MacWebVocabularyCard) -> Bool {
        lhs.item == rhs.item
            && lhs.isSelected == rhs.isSelected
            && lhs.isSpeaking == rhs.isSpeaking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row (`row-main`): Word (or Hanzi Tianzige Tiles) + Speak + Favorite + Level Badge
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        if item.language == .chinese, VocaDesign.containsHanCharacters(item.term) {
                            MacHanziWritingGuide(
                                word: item.term,
                                compact: true,
                                onCharacterFocus: onFocusHanzi
                            )
                        } else {
                            Text(item.term)
                                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        Button {
                            onSpeak()
                        } label: {
                            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(isSpeaking ? VocaDesign.brandGreen : .secondary)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(
                                            isSpeaking
                                                ? VocaDesign.brandGreen.opacity(0.16)
                                                : Color.primary.opacity(0.05)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Pronounce \(item.term)")

                        if item.isFavorite {
                            Button {
                                onToggleFavorite()
                            } label: {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(VocaDesign.accentAmber)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if item.language == .chinese,
                       let pronunciation = item.pronunciation,
                       !pronunciation.isEmpty {
                        Text(pronunciation)
                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(VocaDesign.brandGreen)
                            .lineLimit(1)
                    }

                    // Meta Row (`row-meta`): POS Badge + IPA + Topic
                    HStack(spacing: 6) {
                        if let pos = item.partOfSpeech, !pos.isEmpty {
                            MacPOSBadge(partOfSpeech: pos)
                        }

                        if item.language != .chinese,
                           let pronunciation = item.pronunciation,
                           !pronunciation.isEmpty {
                            Text(pronunciation)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let topic = item.topic, !topic.isEmpty {
                            Text("· \(topic)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                MacLevelBadge(level: item.normalizedLevel, showChevron: false)
            }

            // Bottom Meaning Container (`row-meaning-container`)
            HStack(alignment: .top, spacing: 6) {
                Text(item.displayMeaningVi)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: item.language == .chinese ? 158 : 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                        ? VocaDesign.brandGreen.opacity(0.09)
                        : Color(nsColor: .controlBackgroundColor)
                )
        )
        .overlay(alignment: .leading) {
            if isSelected {
                UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(VocaDesign.brandGreen)
                .frame(width: 3.5)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? VocaDesign.brandGreen.opacity(0.55)
                        : Color.primary.opacity(0.09),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Copy Word & Meaning") {
                onCopy()
            }
            Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }
            Button("Pronounce") {
                onSpeak()
            }
            Menu("Set Level") {
                ForEach(["new", "learning", "known", "mastered"], id: \.self) { level in
                    Button(level.capitalized) {
                        onSelectLevel(level)
                    }
                }
            }
            Divider()
            Button("Delete Word", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Web-Style Badges (`level-badge` & `pos-badge`)

private struct MacLevelBadge: View {
    let level: String
    var showChevron = false

    private var tint: Color {
        switch level.lowercased() {
        case "mastered":
            return VocaDesign.brandGreen
        case "known":
            return VocaDesign.accentIndigo
        case "learning":
            return VocaDesign.accentAmber
        default:
            return VocaDesign.accentSky
        }
    }

    private var label: String {
        switch level.lowercased() {
        case "mastered":
            return "Mastered"
        case "known":
            return "Known"
        case "learning":
            return "Learning"
        default:
            return "New"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))

            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct MacPOSBadge: View {
    let partOfSpeech: String

    private var normalized: String {
        let lower = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("noun") || lower == "n" { return "noun" }
        if lower.contains("verb") && !lower.contains("adverb") { return "verb" }
        if lower.contains("adj") { return "adjective" }
        if lower.contains("adv") { return "adverb" }
        if lower.contains("prep") { return "preposition" }
        if lower.contains("conj") { return "conjunction" }
        if lower.contains("phrase") || lower.contains("idiom") { return "phrase" }
        return lower.isEmpty ? "word" : lower
    }

    private var tint: Color {
        switch normalized {
        case "noun":
            return VocaDesign.brandGreen
        case "verb":
            return VocaDesign.accentSky
        case "adjective":
            return VocaDesign.accentIndigo
        case "adverb":
            return VocaDesign.accentAmber
        case "phrase":
            return VocaDesign.accentRose
        default:
            return .secondary
        }
    }

    var body: some View {
        Text(normalized)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(tint.opacity(0.24), lineWidth: 1)
            )
    }
}

// MARK: - Inline Word AI Agent Drawer (`ChatPanel` from Web)

private struct MacWordAgentChatDrawer: View {
    struct ChatTurn: Identifiable {
        let id = UUID()
        let isUser: Bool
        var text: String
    }

    let item: MacVocabularyItem
    let onClose: () -> Void

    @ViewState private var turns: [ChatTurn] = []
    @ViewState private var input = ""
    @ViewState private var isStreaming = false

    private let assistantService = AssistantService()

    private let quickPrompts = [
        "Giải thích nghĩa & cách dùng",
        "3 câu ví dụ thực tế",
        "Bẫy IELTS / Từ dễ nhầm",
        "Tạo quiz nhanh"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                VocaIconBadge(systemImage: "sparkles", tint: VocaDesign.brandGreen, size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Agent")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(VocaDesign.brandGreen)
                    Text(item.term)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                }

                Spacer()

                if !turns.isEmpty {
                    Button {
                        turns.removeAll()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Reset chat")
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Close AI chat")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))

            Divider().opacity(0.6)

            // Body
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if turns.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hỏi AI về “\(item.term)”")
                                .font(.system(size: 14, weight: .bold))

                            Text("Chọn gợi ý bên dưới hoặc nhập câu hỏi bất kỳ để đào sâu cách dùng, collocations và bài tập.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button {
                                        sendPrompt(prompt)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(VocaDesign.brandGreen)
                                            Text(prompt)
                                                .font(.system(size: 12.5, weight: .medium))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .fill(Color(nsColor: .controlBackgroundColor))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                    } else {
                        ForEach(turns) { turn in
                            HStack {
                                if turn.isUser { Spacer(minLength: 28) }
                                if !turn.isUser && turn.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Đang tạo câu trả lời…")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(Color(nsColor: .controlBackgroundColor))
                                    )
                                } else if turn.isUser {
                                    Text(turn.text)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .lineSpacing(3)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(VocaDesign.brandGreen)
                                        )
                                        .textSelection(.enabled)
                                } else {
                                    VocaMarkdownText(content: turn.text)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(Color(nsColor: .controlBackgroundColor))
                                        )
                                }
                                if !turn.isUser { Spacer(minLength: 16) }
                            }
                        }
                    }
                }
                .padding(14)
            }

            Divider().opacity(0.6)

            // Input Bar
            HStack(spacing: 8) {
                TextField("Hỏi về “\(item.term)”…", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .onSubmit {
                        sendPrompt(input)
                    }

                Button {
                    sendPrompt(input)
                } label: {
                    Image(systemName: isStreaming ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(VocaDesign.brandGreen)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isStreaming || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: item.id) { _, _ in
            turns.removeAll()
        }
    }

    private func sendPrompt(_ rawPrompt: String) {
        let trimmed = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        input = ""
        turns.append(ChatTurn(isUser: true, text: trimmed))
        let assistantTurnID = UUID()
        turns.append(ChatTurn(isUser: false, text: ""))
        let assistantIndex = turns.count - 1
        isStreaming = true

        let contextualMessage = """
        Từ vựng đang xem: "\(item.term)" (\(item.partOfSpeech ?? "word"), IPA/Pinyin: \(item.pronunciation ?? "N/A"), nghĩa: \(item.displayMeaningVi)).
        Yêu cầu của người học: \(trimmed)
        """
        _ = assistantTurnID

        Task {
            do {
                let stream = assistantService.chat(message: contextualMessage)
                var accumulated = ""
                for try await delta in stream {
                    accumulated += delta
                    if assistantIndex < turns.count {
                        turns[assistantIndex].text = accumulated
                    }
                }
                isStreaming = false
            } catch {
                if assistantIndex < turns.count {
                    turns[assistantIndex].text = "Không thể kết nối AI Agent: \(error.localizedDescription)"
                }
                isStreaming = false
            }
        }
    }
}

// MARK: - Web-Style Flashcard Deck Overlay (`FlashcardPanel`)

private struct MacFlashcardDeckOverlay: View {
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech

    let items: [MacVocabularyItem]
    let onClose: () -> Void

    @ViewState private var deck: [MacVocabularyItem] = []
    @ViewState private var currentIndex = 0
    @ViewState private var isFlipped = false

    @ViewState private var isRandomOrder = false
    @ViewState private var keyMonitor: Any? = nil

    private var currentCard: MacVocabularyItem? {
        guard !deck.isEmpty, currentIndex >= 0, currentIndex < deck.count else {
            return nil
        }
        return deck[currentIndex]
    }

    private func pronounceCurrentCard() {
        guard let card = currentCard else { return }
        speech.toggle(card.term, language: card.language)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let chars = event.charactersIgnoringModifiers?.lowercased()
            if event.modifierFlags.contains(.command), chars == "p" {
                pronounceCurrentCard()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func levelTint(_ level: String) -> Color {
        switch level.lowercased() {
        case "mastered":
            return VocaDesign.brandGreen
        case "known":
            return VocaDesign.accentIndigo
        case "learning":
            return VocaDesign.accentAmber
        default:
            return VocaDesign.accentSky
        }
    }

    var body: some View {
        ZStack {
            // Frosted Glass Backdrop so background cards don't bleed through
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.42))
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 18) {
                // Top Bar
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        VocaIconBadge(systemImage: "rectangle.stack.fill", tint: VocaDesign.brandGreen, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flashcard Deck")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text("\(deck.isEmpty ? 0 : currentIndex + 1) / \(deck.count) cards")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isRandomOrder.toggle()
                            if isRandomOrder {
                                deck.shuffle()
                            } else {
                                deck = items
                            }
                            currentIndex = 0
                            isFlipped = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                            Text(isRandomOrder ? "Ngẫu nhiên: Bật" : "Ngẫu nhiên")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isRandomOrder ? VocaDesign.brandGreen : .primary)
                    }
                    .buttonStyle(VocaSecondaryButtonStyle(tint: isRandomOrder ? VocaDesign.brandGreen : .primary))
                    .help("Trộn ngẫu nhiên danh sách thẻ")

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Close Flashcards (ESC)")
                }

                // Progress Strip
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(VocaDesign.brandGradient)
                            .frame(
                                width: geo.size.width * CGFloat(
                                    Double(deck.isEmpty ? 0 : currentIndex + 1) / Double(max(deck.count, 1))
                                )
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentIndex)
                    }
                }
                .frame(height: 5)

                // Flashcard Surface with 3D Flip Animation
                if let card = currentCard {
                    ZStack {
                        // FRONT FACE
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                MacPOSBadge(partOfSpeech: card.partOfSpeech ?? "word")
                                if let topic = card.topic, !topic.isEmpty {
                                    Text(topic)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                MacLevelBadge(level: card.normalizedLevel)
                            }

                            Spacer()

                            VStack(spacing: 14) {
                                if card.language == .chinese, VocaDesign.containsHanCharacters(card.term) {
                                    let hanCount = card.term.filter { VocaDesign.containsHanCharacters(String($0)) }.count
                                    let tileSize: CGFloat = hanCount <= 2 ? 80 : (hanCount <= 4 ? 64 : 52)
                                    MacHanziWritingGuide(
                                        word: card.term,
                                        compact: true,
                                        tileSize: tileSize
                                    )
                                } else {
                                    Text(card.term)
                                        .font(
                                            card.language == .chinese
                                                ? VocaDesign.hanziFont(size: 52, weight: .bold)
                                                : .system(size: 38, weight: .bold, design: .rounded)
                                        )
                                        .tracking(card.language == .chinese ? 2.4 : 0)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.75)
                                }

                                if let pronunciation = card.pronunciation, !pronunciation.isEmpty {
                                    Text(pronunciation)
                                        .font(.system(size: 16.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(VocaDesign.brandGreen)
                                }

                                Button {
                                    pronounceCurrentCard()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(
                                            systemName: speech.isSpeaking && speech.speakingText == card.term
                                                ? "stop.fill"
                                                : "speaker.wave.2.fill"
                                        )
                                        Text("Pronounce")
                                        VocaKeycap(label: "⌘P")
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(VocaSecondaryButtonStyle())
                                .keyboardShortcut("p", modifiers: .command)
                                .padding(.top, 2)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                VocaKeycap(label: "Space")
                                Text("Nhấn Space hoặc click vào thẻ để lật xem nghĩa")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .opacity(isFlipped ? 0 : 1)

                        // BACK FACE (Counter-rotated 180deg so text reads right-side-up when flipped)
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                MacPOSBadge(partOfSpeech: card.partOfSpeech ?? "word")
                                Text(card.term)
                                    .font(
                                        card.language == .chinese
                                            ? VocaDesign.hanziFont(size: 14, weight: .bold)
                                            : .system(size: 13.5, weight: .bold)
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                MacLevelBadge(level: card.normalizedLevel)
                            }

                            Spacer()

                            VStack(spacing: 12) {
                                Text(card.displayMeaningVi)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(VocaDesign.brandGreen)
                                    .multilineTextAlignment(.center)

                                if let meaningEn = card.meaningEn, !meaningEn.isEmpty {
                                    Text(meaningEn)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }

                                if let firstExample = card.examples.first {
                                    Text("“\(firstExample)”")
                                        .font(.system(size: 13, weight: .medium))
                                        .italic()
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.top, 4)
                                }
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                VocaKeycap(label: "1–4")
                                Text("Chọn mức độ nhớ bên dưới hoặc nhấn Space để lật lại")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(isFlipped ? 1 : 0)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 290, maxHeight: 330)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                isFlipped
                                    ? VocaDesign.brandGreen.opacity(0.6)
                                    : VocaDesign.brandGreen.opacity(0.32),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.45
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                            isFlipped.toggle()
                        }
                    }
                    .id(card.id)

                    // Row 1: Level Grading Strip (`1 New`, `2 Learning`, `3 Known`, `4 Mastered`)
                    let levels = ["new", "learning", "known", "mastered"]
                    HStack(spacing: 10) {
                        ForEach(Array(levels.enumerated()), id: \.element) { idx, level in
                            let isCurrentLevel = card.normalizedLevel == level
                            let tint = levelTint(level)
                            Button {
                                Task {
                                    await vocabulary.updateLevel(level, for: card.id)
                                }
                                if currentIndex + 1 < deck.count {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        currentIndex += 1
                                        isFlipped = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Circle()
                                        .fill(tint)
                                        .frame(width: 7, height: 7)

                                    Text(level.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isCurrentLevel ? tint : .primary)
                                        .lineLimit(1)

                                    Spacer(minLength: 2)

                                    VocaKeycap(label: "\(idx + 1)")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(
                                            isCurrentLevel
                                                ? tint.opacity(0.14)
                                                : Color(nsColor: .controlBackgroundColor)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(
                                            isCurrentLevel
                                                ? tint.opacity(0.55)
                                                : Color.primary.opacity(0.10),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: [])
                        }
                    }

                    // Row 2: Navigation Controls (`Previous` ← | `Flip` Space | `Next` →)
                    HStack(spacing: 12) {
                        Button {
                            if currentIndex > 0 {
                                withAnimation(.snappy(duration: 0.2)) {
                                    currentIndex -= 1
                                    isFlipped = false
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Previous")
                                    .lineLimit(1)
                                VocaKeycap(label: "←")
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(VocaSecondaryButtonStyle())
                        .disabled(currentIndex == 0)
                        .keyboardShortcut(.leftArrow, modifiers: [])

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                                isFlipped.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(isFlipped ? "Mặt trước" : "Lật thẻ")
                                    .lineLimit(1)
                                VocaKeycap(label: "Space")
                            }
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])

                        Spacer()

                        Button {
                            if currentIndex + 1 < deck.count {
                                withAnimation(.snappy(duration: 0.2)) {
                                    currentIndex += 1
                                    isFlipped = false
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                VocaKeycap(label: "→")
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(VocaPrimaryButtonStyle())
                        .disabled(currentIndex + 1 >= deck.count)
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    }
                }
            }
            .padding(24)
            .frame(minWidth: 460, idealWidth: 640, maxWidth: 680)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 36, y: 14)
            .padding(24)
        }
        .onAppear {
            deck = items
            currentIndex = 0
            isFlipped = false
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }
}

// MARK: - Add Word with AI Sheet (`MacAddWordSheet`)

struct MacAddWordSheet: View {
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(\.dismiss) private var dismiss

    @ViewState private var word: String
    @ViewState private var language: MacVocabularyItem.Language
    @ViewState private var isCreating = false
    @ViewState private var errorMessage: String?
    @FocusState private var isWordFocused: Bool

    private let onCreated: (MacVocabularyItem) -> Void

    init(
        initialWord: String = "",
        initialLanguage: MacVocabularyItem.Language = .english,
        onCreated: @escaping (MacVocabularyItem) -> Void = { _ in }
    ) {
        _word = State(initialValue: initialWord)
        _language = State(initialValue: initialLanguage)
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    VocaIconBadge(systemImage: "sparkles", tint: VocaDesign.brandGreen, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Word with AI")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Auto-generates IPA/Pinyin, meanings, examples & memory tips")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("WORD OR PHRASE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("e.g. resilient, concise, 坚持…", text: $word)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(VocaDesign.brandGreen.opacity(0.45), lineWidth: 1.5)
                    )
                    .focused($isWordFocused)
                    .onSubmit {
                        submit()
                    }

                HStack {
                    Text("LANGUAGE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Language", selection: $language) {
                        ForEach(MacVocabularyItem.Language.allCases, id: \.self) { option in
                            Text(option.webLabel)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }

            if let existingDuplicate {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VocaDesign.accentAmber)
                    Text("“\(existingDuplicate.term)” is already in your dictionary.")
                        .font(.subheadline)
                        .foregroundStyle(VocaDesign.accentAmber)
                }
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(VocaDesign.accentRose)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(VocaDesign.accentRose)
                }
            }

            HStack {
                Spacer()

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isCreating ? "Generating with AI…" : "Create Card")
                    }
                    .frame(minWidth: 140)
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .disabled(
                    isCreating
                    || word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            isWordFocused = true
        }
        .onChange(of: word) { _, newValue in
            errorMessage = nil
            if containsHanCharacters(newValue) {
                language = .chinese
            }
        }
    }

    private var existingDuplicate: MacVocabularyItem? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return vocabulary.items.first {
            $0.term.compare(
                normalized,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    private func submit() {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCreating else { return }

        if let existingDuplicate {
            onCreated(existingDuplicate)
            dismiss()
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let created = try await vocabulary.create(
                    word: trimmed,
                    language: language
                )
                isCreating = false
                onCreated(created)
                dismiss()
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func containsHanCharacters(_ value: String) -> Bool {
        VocaDesign.containsHanCharacters(value)
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = layout(
            proposal: proposal,
            subviews: subviews
        )
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(
                width: bounds.width,
                height: proposal.height
            ),
            subviews: subviews
        )

        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + point.x,
                    y: bounds.minY + point.y
                ),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let maximumWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0, currentX + size.width > maximumWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            points.append(
                CGPoint(x: currentX, y: currentY)
            )

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, currentX - spacing)
        }

        return (
            CGSize(
                width: min(usedWidth, maximumWidth),
                height: currentY + lineHeight
            ),
            points
        )
    }
}

struct MacVocabularyView_Previews: PreviewProvider {
    static var previews: some View {
        MacVocabularyView()
            .frame(width: 1180, height: 760)
    }
}
