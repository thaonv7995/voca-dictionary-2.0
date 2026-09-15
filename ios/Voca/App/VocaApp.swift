import SwiftUI

@main
struct VocaApp: App {
    @State private var auth = AuthStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(router)
                .onOpenURL { router.open($0) }
        }
    }
}
