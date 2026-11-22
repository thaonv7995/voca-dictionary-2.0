import SwiftUI

@main
struct VocaApp: App {
    @State private var auth: AuthStore
    @State private var router = AppRouter()
    @State private var theme = ThemeStore.shared
    @State private var learner = LocalLearnerStore.shared

    init() {
        let authStore = AuthStore()
        authStore.onDidSignOut = {
            VocabRadioPlayer.shared.stop()
            AudioPlayer.shared.stop()
            AudioPrefetchManager.shared.cancel()
            VoiceSettingsStore.shared.reset()
            WidgetSync.clear()
            LocalLearnerStore.shared.reloadIfNeeded(force: true)
        }
        _auth = State(initialValue: authStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(router)
                .environment(theme)
                .environment(learner)
                .onOpenURL { router.open($0) }
        }
    }
}
