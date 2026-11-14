import SwiftUI

/// Switches the whole app between the branded splash, the login flow, and the signed-in shell,
/// while applying the user's selected theme palette and color scheme globally.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                splashView
                    .task { await auth.bootstrap() }
            case .signedOut:
                LoginView()
            case .signedIn:
                HomeView()
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: auth.phase) { _, phase in
            if phase == .signedIn {
                learner.reloadIfNeeded(force: true)
            }
        }
    }

    private var splashView: some View {
        ZStack {
            VocaThemeBackground()
            VStack(spacing: 18) {
                VocaBrandMark(size: 86)
                VStack(spacing: 4) {
                    Text("Voca")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Từ điển & Luyện tập Song ngữ AI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView()
                    .tint(theme.accent)
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}
