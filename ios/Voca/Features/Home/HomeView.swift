import SwiftUI

/// The signed-in shell: five tabs. Settings now lives inside the Profile tab (see ProfileView).
struct HomeView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Hôm nay", systemImage: "sun.max") }

            DictionaryView()
                .tabItem { Label("Kho từ", systemImage: "rectangle.grid.2x2") }

            StudyRootView()
                .tabItem { Label("Học", systemImage: "brain.head.profile") }

            AssistantRootView()
                .tabItem { Label("Trợ lý", systemImage: "sparkles") }

            ProfileView()
                .tabItem { Label("Hồ sơ", systemImage: "person.crop.circle") }
        }
    }
}
