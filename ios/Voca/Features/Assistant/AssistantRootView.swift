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

/// Root of the AI Assistant feature (chat + practice). A horizontally scrollable
/// row of pills switches between the modes (a 5-segment control would overflow);
/// view-models live here so their state survives switching modes.
struct AssistantRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mode: AssistantMode = .chat
    @State private var chatVM = ChatViewModel()
    @State private var drillsVM = DrillsViewModel()
    @State private var readingVM = ReadingViewModel()
    @State private var articleVM = ArticleViewModel()
    @State private var speakingVM = SpeakingViewModel()
    @State private var conversationVM = ConversationViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        modeSidebar
                        Divider()
                        modeContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        modePicker
                        Divider()
                        modeContent
                    }
                }
            }
            .navigationTitle("Trợ lý AI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var modeContent: some View {
        switch mode {
        case .chat: ChatView(vm: chatVM)
        case .drills: DrillsView(vm: drillsVM)
        case .reading: ReadingView(vm: readingVM)
        case .article: ArticleView(vm: articleVM)
        case .speaking: SpeakingView(vm: speakingVM)
        case .conversation: ConversationView(vm: conversationVM)
        }
    }

    private var modeSidebar: some View {
        VStack(spacing: 6) {
            ForEach(AssistantMode.allCases) { item in
                let selected = mode == item
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = item }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? Brand.green : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 210)
        .background(Color(.secondarySystemGroupedBackground))
    }

    /// Scrollable pill row: the selected mode fills with `Brand.green`.
    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssistantMode.allCases) { item in
                    modePill(item)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func modePill(_ item: AssistantMode) -> some View {
        let selected = mode == item
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { mode = item }
        } label: {
            Label(item.title, systemImage: item.icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : Brand.green)
                .background(selected ? Brand.green : Brand.greenSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
