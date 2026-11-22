import SwiftUI

/// The practice modes offered by the assistant tab.
enum AssistantMode: String, CaseIterable, Identifiable {
    case chat, drills, reading, article, speaking, conversation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chat: return "Trò chuyện"
        case .drills: return "Trắc nghiệm"
        case .reading: return "Đọc hiểu"
        case .article: return "Bài báo"
        case .speaking: return "Nói"
        case .conversation: return "Hội thoại"
        }
    }
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .drills: return "checklist"
        case .reading: return "doc.text"
        case .article: return "newspaper"
        case .speaking: return "waveform"
        case .conversation: return "person.2.wave.2"
        }
    }
}

/// Root of the AI Assistant feature (chat + 5 practice studios).
struct AssistantRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var mode: AssistantMode = .chat
    @Namespace private var modeNamespace
    @State private var chatVM = ChatViewModel()
    @State private var drillsVM = DrillsViewModel()
    @State private var readingVM = ReadingViewModel()
    @State private var articleVM = ArticleViewModel()
    @State private var speakingVM = SpeakingViewModel()
    @State private var conversationVM = ConversationViewModel()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                GeometryReader { geo in
                    if horizontalSizeClass == .regular && geo.size.width >= 700 {
                        HStack(spacing: 0) {
                            modeSidebar
                            Divider()
                            modeContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            CardLanguagePicker(selection: $languageRaw)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            modePicker
                            Divider().opacity(0.6)
                            modeContent
                        }
                    }
                }
            }
            .navigationTitle("Trợ lý AI")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { syncLanguage() }
            .onChange(of: languageRaw) { _, _ in syncLanguage() }
            .onChange(of: mode) { oldMode, newMode in
                guard oldMode != newMode else { return }
                if oldMode == .conversation { conversationVM.stopPlayAll() }
                if oldMode == .speaking { speakingVM.stopPlayback() }
            }
            .onDisappear {
                conversationVM.stopPlayAll()
                speakingVM.stopPlayback()
            }
        }
    }

    private func syncLanguage() {
        let lang = language
        chatVM.setLanguage(lang)
        drillsVM.setLanguage(lang)
        readingVM.setLanguage(lang)
        articleVM.setLanguage(lang)
        speakingVM.setLanguage(lang)
        conversationVM.setLanguage(lang)
    }

    @ViewBuilder private var modeContent: some View {
        Group {
            switch mode {
            case .chat: ChatView(vm: chatVM)
            case .drills: DrillsView(vm: drillsVM)
            case .reading: ReadingView(vm: readingVM)
            case .article: ArticleView(vm: articleVM)
            case .speaking: SpeakingView(vm: speakingVM)
            case .conversation: ConversationView(vm: conversationVM)
            }
        }
        .id(mode)
        .transition(.opacity.combined(with: .offset(y: 6)))
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: mode)
    }

    private var modeSidebar: some View {
        VStack(spacing: 8) {
            CardLanguagePicker(selection: $languageRaw)
                .padding(.bottom, 6)
            ForEach(AssistantMode.allCases) { item in
                let selected = mode == item
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = item }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .foregroundStyle(selected ? .white : .primary)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Brand.gradient)
                                    .matchedGeometryEffect(id: "sidebar-mode", in: modeNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 220)
        .background(Brand.cardFill(for: colorScheme).opacity(0.85))
    }

    private var modePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AssistantMode.allCases) { item in
                        modePill(item)
                            .id(item)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onChange(of: mode) { _, newMode in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    proxy.scrollTo(newMode, anchor: .center)
                }
            }
        }
    }

    private func modePill(_ item: AssistantMode) -> some View {
        let selected = mode == item
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = item }
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : Brand.green)
                .background {
                    if selected {
                        Capsule()
                            .fill(Brand.gradient)
                            .matchedGeometryEffect(id: "phone-mode", in: modeNamespace)
                            .shadow(color: Brand.green.opacity(0.24), radius: 5, y: 2)
                    } else {
                        Capsule().fill(Brand.greenSoft)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
