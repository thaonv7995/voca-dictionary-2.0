import SwiftUI

/// The signed-in shell: adaptive five-section TabView on iPhone and styled SplitView on iPad.
struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppRouter.self) private var router
    @Environment(ThemeStore.self) private var theme
    @State private var selectedSection: HomeSection? = .today

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    List(selection: $selectedSection) {
                        Section {
                            HStack(spacing: 12) {
                                VocaBrandMark(size: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Voca")
                                        .font(.headline.weight(.bold))
                                    Text("Anh – Trung AI")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                        }

                        Section("Điều hướng") {
                            ForEach(HomeSection.allCases) { section in
                                Label(section.title, systemImage: section.icon)
                                    .tag(section)
                            }
                        }
                    }
                    .navigationTitle("Voca")
                } detail: {
                    sectionView(selectedSection ?? .today)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                phoneTabs
            }
        }
        .tint(theme.accent)
        .onChange(of: router.pendingCardSlug) { _, slug in
            if slug != nil { selectedSection = .dictionary }
        }
        .onAppear {
            if router.pendingCardSlug != nil { selectedSection = .dictionary }
        }
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedSection) {
            sectionView(.today)
                .tabItem { Label("Hôm nay", systemImage: "sun.max.fill") }
                .tag(HomeSection.today as HomeSection?)

            sectionView(.dictionary)
                .tabItem { Label("Kho từ", systemImage: "rectangle.grid.2x2.fill") }
                .tag(HomeSection.dictionary as HomeSection?)

            sectionView(.study)
                .tabItem { Label("Ôn tập", systemImage: "brain.head.profile") }
                .tag(HomeSection.study as HomeSection?)

            sectionView(.assistant)
                .tabItem { Label("Trợ lý", systemImage: "sparkles") }
                .tag(HomeSection.assistant as HomeSection?)

            sectionView(.profile)
                .tabItem { Label("Hồ sơ", systemImage: "person.crop.circle.fill") }
                .tag(HomeSection.profile as HomeSection?)
        }
    }

    private func sectionView(_ section: HomeSection) -> some View {
        TabSectionHost(section: section).equatable()
    }
}

/// Defers constructing each tab's view and view-models until SwiftUI first needs
/// to display that section, while remaining `Equatable` so parent state updates
/// (tab switching, theme updates, deep links) skip re-evaluating mounted tabs.
private struct TabSectionHost: View, Equatable {
    let section: HomeSection

    var body: some View {
        switch section {
        case .today: TodayView()
        case .dictionary: DictionaryView()
        case .study: StudyRootView()
        case .assistant: AssistantRootView()
        case .profile: ProfileView()
        }
    }
}

private enum HomeSection: String, CaseIterable, Identifiable {
    case today, dictionary, study, assistant, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Hôm nay"
        case .dictionary: "Kho từ"
        case .study: "Ôn tập"
        case .assistant: "Trợ lý AI"
        case .profile: "Hồ sơ"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max.fill"
        case .dictionary: "rectangle.grid.2x2.fill"
        case .study: "brain.head.profile"
        case .assistant: "sparkles"
        case .profile: "person.crop.circle.fill"
        }
    }
}
