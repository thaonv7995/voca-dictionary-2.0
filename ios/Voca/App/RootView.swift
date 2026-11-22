import SwiftUI

/// Switches the whole app between the branded splash, the login flow, and the signed-in shell,
/// while applying the user's selected theme palette and color scheme globally.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner
    @State private var splashBreathing = false

    var body: some View {
        Group {
            switch auth.phase {
            case .loading:
                splashView
                    .transition(.opacity)
            case .signedOut:
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .signedIn:
                HomeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: auth.phase)
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .task {
            // Lives on the root container so switching to `.signedIn` from cached user
            // does not cancel the background `/api/auth/me` verification request.
            await auth.bootstrap()
        }
        .onChange(of: auth.phase) { _, phase in
            if phase == .signedIn || phase == .signedOut {
                learner.reloadIfNeeded(force: true)
            }
            if phase == .signedOut {
                router.clearPending()
            }
        }
    }

    private var splashView: some View {
        ZStack {
            VocaThemeBackground()
            VStack(spacing: 18) {
                VocaBrandMark(size: 86)
                    .scaleEffect(splashBreathing ? 1.04 : 0.97)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: splashBreathing)
                    .onAppear { splashBreathing = true }
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
