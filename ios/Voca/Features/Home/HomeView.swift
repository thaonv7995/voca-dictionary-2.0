import SwiftUI

/// The signed-in shell: five tabs, one per feature area.
struct HomeView: View {
    var body: some View {
        TabView {
            DictionaryView()
                .tabItem { Label("Kho từ", systemImage: "rectangle.grid.2x2") }

            StudyRootView()
                .tabItem { Label("Học", systemImage: "brain.head.profile") }

            AssistantRootView()
                .tabItem { Label("Trợ lý", systemImage: "sparkles") }

            SettingsRootView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape") }

            ProfileView()
                .tabItem { Label("Hồ sơ", systemImage: "person.crop.circle") }
        }
    }
}
