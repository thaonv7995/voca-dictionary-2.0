import SwiftUI

/// The practice modes offered by the assistant tab.
enum AssistantMode: String, CaseIterable, Identifiable {
    case chat, drills, reading, article, speaking
    var id: String { rawValue }
    var title: String {
        switch self {
        case .chat: return "Trò chuyện"
        case .drills: return "Trắc nghiệm"
        case .reading: return "Đọc hiểu"
        case .article: return "Bài báo"
        case .speaking: return "Nói"
        }
    }
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .drills: return "checklist"
        case .reading: return "doc.text"
        case .article: return "newspaper"
        case .speaking: return "waveform"
        }
    }
}

/// Root of the AI Assistant feature (chat + practice). A horizontally scrollable
/// row of pills switches between the modes (a 5-segment control would overflow);
/// view-models live here so their state survives switching modes.
struct AssistantRootView: View {
    @State private var mode: AssistantMode = .chat
    @State private var chatVM = ChatViewModel()
    @State private var drillsVM = DrillsViewModel()
    @State private var readingVM = ReadingViewModel()
    @State private var articleVM = ArticleViewModel()
    @State private var speakingVM = SpeakingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker

                Divider()

                switch mode {
                case .chat: ChatView(vm: chatVM)
                case .drills: DrillsView(vm: drillsVM)
                case .reading: ReadingView(vm: readingVM)
                case .article: ArticleView(vm: articleVM)
                case .speaking: SpeakingView(vm: speakingVM)
                }
            }
            .navigationTitle("Trợ lý AI")
            .navigationBarTitleDisplayMode(.inline)
        }
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
