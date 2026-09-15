import SwiftUI

@main
struct VocaApp: App {
    @State private var auth = AuthStore()
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase
    private let widgetRouteTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(router)
                .onOpenURL { router.open($0) }
                .onAppear { router.openPendingWidgetCard() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { router.openPendingWidgetCard() }
                }
                .onReceive(widgetRouteTimer) { _ in
                    if scenePhase == .active { router.openPendingWidgetCard() }
                }
        }
    }
}
