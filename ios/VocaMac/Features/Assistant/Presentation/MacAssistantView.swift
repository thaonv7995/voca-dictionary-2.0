import AppKit
import SwiftUI

struct MacAssistantMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String

    init(
        id: UUID = UUID(),
        role: Role,
        content: String
    ) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct MacAssistantView: View {
    enum ContextScopeMode: String, CaseIterable, Identifiable {
        case custom
        case allLanguageWords
        case byLevel
        case byTopic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .custom:
                return "Tự chọn"
            case .allLanguageWords:
                return "Tất cả từ"
            case .byLevel:
                return "Theo Level"
            case .byTopic:
                return "Theo Chủ đề"
            }
        }
    }

    @Environment(MacVocabularyStore.self) private var vocabulary

    @ViewState private var activeLanguage: MacVocabularyItem.Language = .english
    @ViewState private var englishMessages: [MacAssistantMessage] = [
        MacAssistantMessage(
            role: .assistant,
            content: "Xin chào! Mình là **Trợ lý Tiếng Anh AI**. Hãy chọn phạm vi từ vựng ở cột bên phải hoặc đặt câu hỏi để mình giải thích sắc thái nghĩa, collocations, đặt câu ví dụ hoặc tạo bài trắc nghiệm IELTS/TOEIC."
        )
    ]
    @ViewState private var chineseMessages: [MacAssistantMessage] = [
        MacAssistantMessage(
            role: .assistant,
            content: "Xin chào! Mình là **Gia sư Hán ngữ AI (中文)**. Hãy chọn từ vựng chữ Hán ở cột bên phải hoặc đặt câu hỏi để mình phân tích **âm Hán Việt, bộ thủ, Pinyin**, so sánh từ gần nghĩa và tạo câu đố nhớ mặt chữ."
        )
    ]
    @ViewState private var prompt = ""
    @ViewState private var contextSearchQuery = ""
    @ViewState private var contextScopeMode: ContextScopeMode = .allLanguageWords
    @ViewState private var contextLevelFilter: String = "learning"
    @ViewState private var contextTopicFilter: String = ""
    @ViewState private var isContextInspectorVisible = true
    @ViewState private var selectedEnglishIDs: Set<MacVocabularyItem.ID> = []
    @ViewState private var selectedChineseIDs: Set<MacVocabularyItem.ID> = []
    @ViewState private var isGenerating = false
    @ViewState private var generationTask: Task<Void, Never>?
    @ViewState private var generationError: String?
    @ViewState private var copiedMessageID: UUID?
    @FocusState private var isPromptFocused: Bool

    private var messages: [MacAssistantMessage] {
        activeLanguage == .chinese ? chineseMessages : englishMessages
    }

    private func setMessages(_ updated: [MacAssistantMessage], for language: MacVocabularyItem.Language) {
        if language == .chinese {
            chineseMessages = updated
        } else {
            englishMessages = updated
        }
    }

    private var selectedVocabularyIDs: Set<MacVocabularyItem.ID> {
        activeLanguage == .chinese ? selectedChineseIDs : selectedEnglishIDs
    }

    private func setSelectedVocabularyIDs(_ updated: Set<MacVocabularyItem.ID>) {
        if activeLanguage == .chinese {
            selectedChineseIDs = updated
        } else {
            selectedEnglishIDs = updated
        }
    }

    private var starterPrompts: [(icon: String, title: String, prompt: String)] {
        if activeLanguage == .chinese {
            return [
                (
                    "character.textbox",
                    "Phân tích Hán Việt & Bộ thủ",
                    "Phân tích âm Hán Việt, cấu tạo bộ thủ và mẹo nhớ mặt chữ cho các từ chữ Hán trong ngữ cảnh"
                ),
                (
                    "text.quote",
                    "Đặt câu ví dụ kèm Pinyin",
                    "Đặt câu giao tiếp thực tế có kèm Pinyin và nghĩa tiếng Việt cho các từ chữ Hán trong ngữ cảnh"
                ),
                (
                    "checklist",
                    "Đố vui nhớ mặt chữ & Pinyin",
                    "Tạo 5 câu hỏi trắc nghiệm đố vui giúp nhớ mặt chữ Hán, Pinyin và nghĩa kèm giải thích"
                ),
                (
                    "arrow.left.and.right.circle.fill",
                    "So sánh từ Hán ngữ gần nghĩa",
                    "So sánh sự khác biệt về ngữ cảnh sử dụng giữa các từ chữ Hán dễ nhầm lẫn trong danh sách"
                )
            ]
        } else {
            return [
                (
                    "arrow.left.and.right.circle.fill",
                    "So sánh sắc thái nghĩa",
                    "So sánh sắc thái nghĩa và cách dùng của các từ vựng tiếng Anh trong ngữ cảnh"
                ),
                (
                    "doc.text.fill",
                    "Viết đoạn văn ứng dụng",
                    "Viết một đoạn văn ngắn tự nhiên ứng dụng các từ vựng tiếng Anh trong ngữ cảnh kèm bản dịch"
                ),
                (
                    "checklist",
                    "Tạo 5 câu trắc nghiệm",
                    "Tạo 5 câu hỏi trắc nghiệm ôn tập từ vựng tiếng Anh kèm đáp án và giải thích chi tiết"
                ),
                (
                    "lightbulb.fill",
                    "Collocations & Bẫy IELTS/TOEIC",
                    "Giải thích các collocations phổ biến và các lỗi/bẫy TOEIC, IELTS hay gặp của các từ này"
                )
            ]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let isCompact = totalWidth < 800
            let inspectorWidth = min(max(totalWidth * 0.30, 270), 350)

            ZStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    conversation
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)

                    if isContextInspectorVisible && !isCompact {
                        Divider().opacity(0.6)
                        contextInspector
                            .frame(width: inspectorWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isContextInspectorVisible && isCompact {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.18)) {
                                isContextInspectorVisible = false
                            }
                        }

                    contextInspector
                        .frame(width: min(max(totalWidth * 0.82, 270), 350))
                        .frame(maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: -6, y: 0)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Assistant")
        .background(VocaDesign.subtleWindowBackground)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    startNewConversation()
                } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("Cuộc trò chuyện mới (⇧⌘N)")

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isContextInspectorVisible.toggle()
                    }
                } label: {
                    Label("Vocabulary Context", systemImage: "sidebar.trailing")
                }
                .help("Ẩn/Hiện danh sách từ vựng ngữ cảnh")
            }
        }
        .onAppear {
            isPromptFocused = true
        }
        .task {
            await vocabulary.load()
        }
        .alert(
            "Assistant Request Failed",
            isPresented: Binding(
                get: { generationError != nil },
                set: { isPresented in
                    if !isPresented {
                        generationError = nil
                    }
                }
            )
        ) {
            Button("OK") {
                generationError = nil
            }
        } message: {
            Text(
                generationError
                    ?? "The Assistant could not complete this request."
            )
        }
        .onDisappear {
            generationTask?.cancel()
        }
    }

    // MARK: - Top Header Bar

    private var assistantHeaderBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                headerIdentityBlock
                Spacer(minLength: 8)
                languageContextSwitcher
                headerActionButtons
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    headerIdentityBlock
                    Spacer()
                    languageContextSwitcher
                }
                HStack {
                    Spacer()
                    headerActionButtons
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
    }

    private var headerIdentityBlock: some View {
        HStack(spacing: 12) {
            VocaIconBadge(
                systemImage: activeLanguage == .chinese ? "character.book.closed.fill" : "sparkles",
                tint: activeLanguage == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen,
                size: 34,
                iconSize: 16
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(
                        activeLanguage == .chinese
                            ? "Gia sư Hán ngữ AI (中文)"
                            : "AI Vocabulary Assistant (English)"
                    )
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                    if isGenerating {
                        VocaPillBadge(
                            text: "Đang trả lời…",
                            icon: "ellipsis.bubble.fill",
                            tint: VocaDesign.brandGreen
                        )
                    }
                }

                Text(activeContextSummaryText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var languageContextSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(MacVocabularyItem.Language.allCases, id: \.self) { lang in
                let isSelected = activeLanguage == lang
                let count = vocabulary.items.filter { $0.language == lang }.count
                Button {
                    guard activeLanguage != lang else { return }
                    withAnimation(.snappy(duration: 0.2)) {
                        activeLanguage = lang
                        contextTopicFilter = ""
                        contextSearchQuery = ""
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(lang == .chinese ? "中文 Chữ Hán" : "English")
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        Text("\(count)")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                            )
                    }
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                isSelected
                                    ? (lang == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen)
                                    : Color.clear
                            )
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
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .help("Chuyển đổi ngữ cảnh giữa Tiếng Anh (English) và Chữ Hán (中文)")
    }

    private var headerActionButtons: some View {
        HStack(spacing: 8) {
            if messages.count > 1 {
                Button {
                    startNewConversation()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("Làm mới")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .help("Bắt đầu cuộc trò chuyện mới (⇧⌘N)")
            }

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    isContextInspectorVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.trailing")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("Ngữ cảnh (\(activeContextVocabulary.count))")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(
                VocaSecondaryButtonStyle(
                    tint: activeContextVocabulary.isEmpty ? .primary : VocaDesign.brandGreen
                )
            )
        }
    }

    // MARK: - Conversation Area

    private var conversation: some View {
        VStack(spacing: 0) {
            assistantHeaderBar
            Divider().opacity(0.6)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if messages.count <= 1 {
                            starterSuggestionsGrid
                        }

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }
                .onChange(of: messages.count) { _, _ in
                    guard let lastID = messages.last?.id else { return }
                    withAnimation(.snappy(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                .onChange(of: messages.last?.content) { _, _ in
                    guard let lastID = messages.last?.id else { return }
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }

            Divider().opacity(0.6)

            composer
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    VocaPillBadge(
                        text: activeLanguage == .chinese ? "Ngữ cảnh: 中文 Chữ Hán" : "Ngữ cảnh: English",
                        icon: "globe",
                        tint: activeLanguage == .chinese ? VocaDesign.accentAmber : VocaDesign.accentSky
                    )

                    VocaPillBadge(
                        text: "\(contextScopeMode.title) · \(activeContextVocabulary.count) từ",
                        icon: "checkmark.seal.fill",
                        tint: VocaDesign.brandGreen
                    )

                    if contextScopeMode == .custom {
                        ForEach(activeContextVocabulary.prefix(8)) { item in
                            HStack(spacing: 4) {
                                Text(item.term)
                                    .font(.system(size: 11.5, weight: .semibold))
                                Button {
                                    var updated = selectedVocabularyIDs
                                    updated.remove(item.id)
                                    setSelectedVocabularyIDs(updated)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8.5, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            activeLanguage == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen
                        )

                    TextField(
                        activeLanguage == .chinese
                            ? "Hỏi trợ lý Hán ngữ (vd: giải nghĩa Hán Việt, bộ thủ, Pinyin, đặt câu)…"
                            : "Nhập câu hỏi về từ vựng tiếng Anh, ngữ pháp, ví dụ hoặc bài tập…",
                        text: $prompt,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .lineLimit(1...6)
                    .focused($isPromptFocused)
                    .onSubmit {
                        send()
                    }

                    if !prompt.isEmpty {
                        Button {
                            prompt = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isPromptFocused
                                ? VocaDesign.brandGreen.opacity(0.75)
                                : Color.primary.opacity(0.12),
                            lineWidth: isPromptFocused ? 1.5 : 1
                        )
                )

                if isGenerating {
                    Button {
                        cancelGeneration()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Dừng")
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(VocaSecondaryButtonStyle(tint: VocaDesign.accentRose))
                } else {
                    Button {
                        send()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Gửi")
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .disabled(normalizedPrompt.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }

            HStack {
                Text("Nhấn Enter hoặc ⌘↩ để gửi · Chọn từ vựng ở cột phải để AI tạo bài tập sát với sổ từ của bạn.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
    }

    private var starterSuggestionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GỢI Ý CÂU HỎI NHANH")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 230, maximum: 420), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(starterPrompts, id: \.title) { item in
                    Button {
                        prompt = item.prompt
                        send()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VocaDesign.brandGreen)
                                .frame(width: 28, height: 28)
                                .background(
                                    VocaDesign.brandGreen.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(item.prompt)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var languageScopedVocabulary: [MacVocabularyItem] {
        vocabulary.items.filter { $0.language == activeLanguage }
    }

    private var availableContextTopics: [String] {
        let topics = Set(
            languageScopedVocabulary.compactMap { item -> String? in
                guard let t = item.topic?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
                    return nil
                }
                return t
            }
        )
        return topics.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var activeContextVocabulary: [MacVocabularyItem] {
        switch contextScopeMode {
        case .allLanguageWords:
            return languageScopedVocabulary
        case .byLevel:
            return languageScopedVocabulary.filter { $0.normalizedLevel == contextLevelFilter }
        case .byTopic:
            guard !contextTopicFilter.isEmpty else { return languageScopedVocabulary }
            return languageScopedVocabulary.filter {
                $0.topic?.caseInsensitiveCompare(contextTopicFilter) == .orderedSame
            }
        case .custom:
            let ids = selectedVocabularyIDs
            if ids.isEmpty {
                return []
            }
            return languageScopedVocabulary.filter { ids.contains($0.id) }
        }
    }

    private var activeContextSummaryText: String {
        let langLabel = activeLanguage == .chinese ? "Chữ Hán (中文)" : "Tiếng Anh (English)"
        switch contextScopeMode {
        case .allLanguageWords:
            return "Ngữ cảnh: Toàn bộ \(activeContextVocabulary.count) từ \(langLabel)"
        case .byLevel:
            return "Ngữ cảnh: \(activeContextVocabulary.count) từ \(langLabel) · Cấp độ \(contextLevelFilter.capitalized)"
        case .byTopic:
            let topicText = contextTopicFilter.isEmpty ? "Tất cả chủ đề" : contextTopicFilter
            return "Ngữ cảnh: \(activeContextVocabulary.count) từ \(langLabel) · Chủ đề \(topicText)"
        case .custom:
            return selectedVocabularyIDs.isEmpty
                ? "Ngữ cảnh: Chưa chọn từ \(langLabel) cụ thể (chọn ở cột phải)"
                : "Ngữ cảnh: Đã chọn \(selectedVocabularyIDs.count) từ \(langLabel)"
        }
    }

    private var filteredContextVocabulary: [MacVocabularyItem] {
        let baseList: [MacVocabularyItem]
        switch contextScopeMode {
        case .byLevel:
            baseList = languageScopedVocabulary.filter { $0.normalizedLevel == contextLevelFilter }
        case .byTopic:
            baseList = contextTopicFilter.isEmpty
                ? languageScopedVocabulary
                : languageScopedVocabulary.filter {
                    $0.topic?.caseInsensitiveCompare(contextTopicFilter) == .orderedSame
                }
        case .allLanguageWords, .custom:
            baseList = languageScopedVocabulary
        }

        let q = contextSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return baseList }
        return baseList.filter { item in
            item.term.lowercased().contains(q)
                || (item.pronunciation?.lowercased().contains(q) == true)
                || item.displayMeaningVi.lowercased().contains(q)
                || (item.topic?.lowercased().contains(q) == true)
        }
    }

    private var contextInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(activeLanguage == .chinese ? "Ngữ cảnh Chữ Hán" : "Ngữ cảnh Tiếng Anh")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                    Spacer()
                    VocaPillBadge(
                        text: "\(activeContextVocabulary.count) từ",
                        tint: activeLanguage == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen
                    )
                }

                // Scope Mode Picker (`Tất cả từ` | `Theo Level` | `Theo Chủ đề` | `Tự chọn`)
                VStack(alignment: .leading, spacing: 6) {
                    Text("PHẠM VI NGỮ CẢNH (CONTEXT SCOPE)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ],
                        spacing: 6
                    ) {
                        ForEach(ContextScopeMode.allCases) { mode in
                            let isSelected = contextScopeMode == mode
                            Button {
                                withAnimation(.snappy(duration: 0.18)) {
                                    contextScopeMode = mode
                                }
                            } label: {
                                Text(mode.title)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? VocaDesign.brandGreen
                                                    : Color(nsColor: .textBackgroundColor)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                isSelected
                                                    ? VocaDesign.brandGreen
                                                    : Color.primary.opacity(0.10),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if contextScopeMode == .byLevel {
                    HStack(spacing: 6) {
                        ForEach(["new", "learning", "known", "mastered"], id: \.self) { lvl in
                            let active = contextLevelFilter == lvl
                            Button {
                                contextLevelFilter = lvl
                            } label: {
                                Text(lvl.capitalized)
                                    .font(.system(size: 11, weight: active ? .bold : .medium))
                                    .foregroundStyle(active ? VocaDesign.brandGreen : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(active ? VocaDesign.brandGreen.opacity(0.14) : Color.primary.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if contextScopeMode == .byTopic {
                    Menu {
                        Button("Tất cả chủ đề") {
                            contextTopicFilter = ""
                        }
                        Divider()
                        ForEach(availableContextTopics, id: \.self) { topic in
                            Button(topic) {
                                contextTopicFilter = topic
                            }
                        }
                    } label: {
                        HStack {
                            Text(contextTopicFilter.isEmpty ? "Tất cả chủ đề" : contextTopicFilter)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        activeLanguage == .chinese
                            ? "Tìm chữ Hán, Pinyin, nghĩa…"
                            : "Tìm từ tiếng Anh, nghĩa, chủ đề…",
                        text: $contextSearchQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    if !contextSearchQuery.isEmpty {
                        Button {
                            contextSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
            }
            .padding(16)

            Divider().opacity(0.6)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredContextVocabulary) { item in
                        let isSelected = contextScopeMode == .custom
                            ? selectedVocabularyIDs.contains(item.id)
                            : true
                        HStack(spacing: 10) {
                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                isSelected
                                    ? (activeLanguage == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen)
                                    : Color.secondary.opacity(0.5)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.term)
                                        .font(
                                            item.language == .chinese
                                                ? VocaDesign.hanziFont(size: 18, weight: .bold)
                                                : .system(size: 13.5, weight: .semibold, design: .rounded)
                                        )
                                        .tracking(item.language == .chinese ? 1.0 : 0)
                                    if let pronunciation = item.pronunciation {
                                        Text(pronunciation)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(
                                                item.language == .chinese ? VocaDesign.brandGreen : .secondary
                                            )
                                            .lineLimit(1)
                                    }
                                }

                                Text(item.displayMeaningVi)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(
                                    isSelected && contextScopeMode == .custom
                                        ? VocaDesign.brandGreen.opacity(0.10)
                                        : Color.clear
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .onTapGesture {
                            if contextScopeMode != .custom {
                                contextScopeMode = .custom
                                setSelectedVocabularyIDs([item.id])
                            } else {
                                toggleContext(item.id)
                            }
                        }
                    }
                }
                .padding(10)
            }

            Divider().opacity(0.6)

            HStack {
                Button("Chọn tất cả") {
                    contextScopeMode = .custom
                    setSelectedVocabularyIDs(
                        Set(filteredContextVocabulary.map(\.id))
                    )
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .disabled(filteredContextVocabulary.isEmpty)

                Spacer()

                Button("Bỏ chọn") {
                    contextScopeMode = .custom
                    setSelectedVocabularyIDs([])
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .disabled(selectedVocabularyIDs.isEmpty && contextScopeMode == .custom)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))
    }

    @ViewBuilder
    private func messageBubble(
        _ message: MacAssistantMessage
    ) -> some View {
        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if message.role == .user {
            HStack(alignment: .top, spacing: 10) {
                Spacer(minLength: 90)

                Text(message.content)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VocaDesign.brandGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: VocaDesign.brandGreen.opacity(0.18), radius: 8, y: 3)

                VocaIconBadge(
                    systemImage: "person.fill",
                    tint: VocaDesign.accentSky,
                    size: 32,
                    iconSize: 14
                )
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your message")
        } else {
            HStack(alignment: .top, spacing: 12) {
                VocaIconBadge(
                    systemImage: "sparkles",
                    tint: VocaDesign.brandGreen,
                    size: 32,
                    iconSize: 15
                )
                .accessibilityHidden(true)

                if trimmedContent.isEmpty {
                    // Inline Generating State (replaces the empty ghost bubble + duplicate row)
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Đang suy nghĩ & tạo câu trả lời…")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(VocaDesign.brandGreen.opacity(0.28), lineWidth: 1)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        VocaMarkdownText(content: message.content)

                        if messages.first?.id != message.id {
                            Divider().opacity(0.45)

                            HStack(spacing: 12) {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.content, forType: .string)
                                    copiedMessageID = message.id
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                                        if copiedMessageID == message.id {
                                            copiedMessageID = nil
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(
                                            systemName: copiedMessageID == message.id
                                                ? "checkmark.circle.fill"
                                                : "doc.on.doc"
                                        )
                                        .font(.system(size: 11, weight: .semibold))
                                        Text(copiedMessageID == message.id ? "Đã sao chép" : "Sao chép")
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .foregroundStyle(
                                        copiedMessageID == message.id
                                            ? VocaDesign.brandGreen
                                            : .secondary
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 660, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }

                Spacer(minLength: 48)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Assistant message")
        }
    }

    private var normalizedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let submittedPrompt = normalizedPrompt

        guard !submittedPrompt.isEmpty, !isGenerating else {
            return
        }

        let targetLang = activeLanguage
        var currentList = messages
        currentList.append(
            MacAssistantMessage(
                role: .user,
                content: submittedPrompt
            )
        )
        prompt = ""
        isGenerating = true

        let groundedVocabulary = activeContextVocabulary
        let groundedPrompt = assistantPrompt(
            prompt: submittedPrompt,
            vocabulary: groundedVocabulary,
            language: targetLang
        )
        let assistantMessageID = UUID()

        currentList.append(
            MacAssistantMessage(
                id: assistantMessageID,
                role: .assistant,
                content: ""
            )
        )
        setMessages(currentList, for: targetLang)

        generationTask?.cancel()
        generationTask = Task {
            do {
                for try await chunk in AssistantService().chat(
                    message: groundedPrompt,
                    language: targetLang == .chinese ? .chinese : .english
                ) {
                    try Task.checkCancellation()

                    var updatedList = targetLang == .chinese ? chineseMessages : englishMessages
                    guard let index = updatedList.firstIndex(where: {
                        $0.id == assistantMessageID
                    }) else {
                        continue
                    }

                    updatedList[index].content += chunk
                    setMessages(updatedList, for: targetLang)
                }

                var finalList = targetLang == .chinese ? chineseMessages : englishMessages
                if let index = finalList.firstIndex(where: {
                    $0.id == assistantMessageID
                }),
                   finalList[index].content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    finalList[index].content =
                        "The Assistant returned an empty response."
                    setMessages(finalList, for: targetLang)
                }
            } catch is CancellationError {
                var canceledList = targetLang == .chinese ? chineseMessages : englishMessages
                canceledList.removeAll(where: {
                    $0.id == assistantMessageID
                    && $0.content.isEmpty
                })
                setMessages(canceledList, for: targetLang)
            } catch {
                var erroredList = targetLang == .chinese ? chineseMessages : englishMessages
                erroredList.removeAll(where: {
                    $0.id == assistantMessageID
                    && $0.content.isEmpty
                })
                setMessages(erroredList, for: targetLang)
                generationError = error.localizedDescription
            }

            isGenerating = false
            generationTask = nil
            isPromptFocused = true
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        isPromptFocused = true
    }

    private func startNewConversation() {
        generationTask?.cancel()
        generationTask = nil
        if activeLanguage == .chinese {
            chineseMessages = [
                MacAssistantMessage(
                    role: .assistant,
                    content: "Bạn muốn ôn tập chữ Hán (中文), phân tích bộ thủ, Pinyin hay làm câu đố từ vựng nào?"
                )
            ]
        } else {
            englishMessages = [
                MacAssistantMessage(
                    role: .assistant,
                    content: "Bạn muốn ôn tập từ vựng tiếng Anh, so sánh từ đồng nghĩa hay tạo bài tập trắc nghiệm nào?"
                )
            ]
        }
        prompt = ""
        isGenerating = false
        isPromptFocused = true
    }

    private func toggleContext(_ identifier: MacVocabularyItem.ID) {
        var current = selectedVocabularyIDs
        if current.contains(identifier) {
            current.remove(identifier)
        } else {
            current.insert(identifier)
        }
        setSelectedVocabularyIDs(current)
    }

    private func assistantPrompt(
        prompt: String,
        vocabulary: [MacVocabularyItem],
        language: MacVocabularyItem.Language
    ) -> String {
        let roleInstruction = language == .chinese
            ? "Bạn là Gia sư Hán ngữ AI (Chinese Language Tutor). Khi giải thích, so sánh hoặc tạo bài tập/ví dụ, hãy luôn kèm theo Chữ Hán (Hanzi), Pinyin chuẩn thanh điệu, âm Hán Việt (nếu có) và nghĩa tiếng Việt rõ ràng."
            : "Bạn là Gia sư Tiếng Anh AI (English Vocabulary & IELTS/TOEIC Tutor). Hãy giải thích rõ ràng bằng tiếng Việt kết hợp ví dụ tiếng Anh tự nhiên."

        guard !vocabulary.isEmpty else {
            return """
            [\(roleInstruction)]
            Yêu cầu của người học: \(prompt)
            """
        }

        let cappedVocabulary = Array(vocabulary.prefix(60))
        let context = cappedVocabulary.map { item in
            let pronunciation = item.pronunciation.map {
                " (\($0))"
            } ?? ""

            return "- \(item.term)\(pronunciation): \(item.displayMeaningVi)"
        }
        .joined(separator: "\n")

        return """
        [\(roleInstruction)]
        Yêu cầu của người học: \(prompt)

        Hãy ưu tiên sử dụng các từ vựng (\(language == .chinese ? "Chữ Hán / Tiếng Trung" : "Tiếng Anh")) trong ngữ cảnh dưới đây khi trả lời:
        \(context)
        """
    }
}

// MARK: - Rich Markdown Renderer for AI Assistant Messages

struct VocaMarkdownText: View {
    let content: String

    private var lines: [String] {
        content.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, rawLine in
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                let hasHanzi = VocaDesign.containsHanCharacters(trimmed)
                if trimmed.isEmpty {
                    Spacer().frame(height: 2)
                } else if trimmed.hasPrefix("### ") {
                    inlineMarkdownText(String(trimmed.dropFirst(4)))
                        .font(
                            hasHanzi
                                ? VocaDesign.hanziFont(size: 15.5, weight: .bold)
                                : .system(size: 14.5, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(VocaDesign.brandGreen)
                        .padding(.top, 4)
                } else if trimmed.hasPrefix("## ") {
                    inlineMarkdownText(String(trimmed.dropFirst(3)))
                        .font(
                            hasHanzi
                                ? VocaDesign.hanziFont(size: 16.5, weight: .bold)
                                : .system(size: 15.5, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(VocaDesign.brandGreen)
                        .padding(.top, 6)
                } else if trimmed.hasPrefix("# ") {
                    inlineMarkdownText(String(trimmed.dropFirst(2)))
                        .font(
                            hasHanzi
                                ? VocaDesign.hanziFont(size: 17.5, weight: .bold)
                                : .system(size: 16.5, weight: .bold, design: .rounded)
                        )
                        .padding(.top, 6)
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(VocaDesign.brandGreen)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        inlineMarkdownText(String(trimmed.dropFirst(2)))
                            .font(
                                hasHanzi
                                    ? VocaDesign.hanziFont(size: 15, weight: .regular)
                                    : .system(size: 13.8)
                            )
                            .lineSpacing(hasHanzi ? 4.5 : 3)
                    }
                    .padding(.leading, 4)
                } else {
                    inlineMarkdownText(rawLine)
                        .font(
                            hasHanzi
                                ? VocaDesign.hanziFont(size: 15, weight: .regular)
                                : .system(size: 13.8)
                        )
                        .lineSpacing(hasHanzi ? 4.5 : 3)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func inlineMarkdownText(_ raw: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attributed)
        }
        return Text(raw)
    }
}

struct MacAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        MacAssistantView()
            .environment(
                MacVocabularyStore(
                    repository: PreviewMacVocabularyRepository()
                )
            )
            .frame(width: 1080, height: 760)
    }
}
