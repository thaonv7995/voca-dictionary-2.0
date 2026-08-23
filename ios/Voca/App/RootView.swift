import SwiftUI

/// Switches the whole app between the loading splash, the login flow, and the signed-in shell,
/// driven by `AuthStore.phase`.
struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        switch auth.phase {
        case .loading:
            ProgressView("Đang tải…")
                .task { await auth.bootstrap() }
        case .signedOut:
            LoginView()
        case .signedIn:
            HomeView()
        }
    }
}
