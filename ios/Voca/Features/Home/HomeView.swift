import SwiftUI

/// The signed-in shell: five tabs. Settings now lives inside the Profile tab (see ProfileView).
struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: HomeSection? = .today

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(HomeSection.allCases, selection: $selectedSection) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
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

    private var phoneTabs: some View {
        TabView {
            sectionView(.today)
                .tabItem { Label("Hôm nay", systemImage: "sun.max") }

            sectionView(.dictionary)
                .tabItem { Label("Kho từ", systemImage: "rectangle.grid.2x2") }

            sectionView(.study)
                .tabItem { Label("Học", systemImage: "brain.head.profile") }

            sectionView(.assistant)
                .tabItem { Label("Trợ lý", systemImage: "sparkles") }

            sectionView(.profile)
                .tabItem { Label("Hồ sơ", systemImage: "person.crop.circle") }
        }
    }

    @ViewBuilder private func sectionView(_ section: HomeSection) -> some View {
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
        case .study: "Học tập"
        case .assistant: "Trợ lý AI"
        case .profile: "Hồ sơ"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .dictionary: "rectangle.grid.2x2"
        case .study: "brain.head.profile"
        case .assistant: "sparkles"
        case .profile: "person.crop.circle"
        }
    }
}
