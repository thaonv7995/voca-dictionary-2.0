import AppKit
import CoreSpotlight
import Foundation
import ServiceManagement
import UserNotifications

enum MacSystemIntegrations {
    static let spotlightDomainIdentifier = "site.thaonv.voca.macos.vocabulary"

    @MainActor
    @discardableResult
    static func updateLaunchAtLogin(enabled: Bool) -> (success: Bool, error: String?) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @MainActor
    static var launchAtLoginStatus: SMAppService.Status {
        SMAppService.mainApp.status
    }

    @MainActor
    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @MainActor
    static func updateDockIconVisibility(hideDockIcon: Bool) {
        guard let app = NSApp else { return }
        let targetPolicy: NSApplication.ActivationPolicy = hideDockIcon ? .accessory : .regular
        if app.activationPolicy() != targetPolicy {
            app.setActivationPolicy(targetPolicy)
            if !hideDockIcon {
                app.activate(ignoringOtherApps: true)
            }
        }
    }

    @MainActor
    static func dismissMenuBarPopoverIfNeeded() {
        guard let app = NSApp else { return }
        for window in app.windows where window.isVisible {
            let className = window.className
            if className.contains("MenuBarExtraWindow")
                || className.contains("NSStatusBarWindow") {
                if className.contains("MenuBarExtraWindow") {
                    window.orderOut(nil)
                }
            }
        }
    }

    @MainActor
    static func bringMainWindowsToFront() {
        DispatchQueue.main.async {
            guard let app = NSApp else { return }
            app.activate(ignoringOtherApps: true)
            for window in app.windows {
                let className = window.className
                guard !window.isMiniaturized,
                      !window.isFloatingPanel,
                      !className.contains("StatusBar"),
                      !className.contains("MenuBarExtra")
                else {
                    continue
                }
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }

    static func indexVocabularyInSpotlight(_ items: [MacVocabularyItem]) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let searchableItems = items.map { item in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = item.term
            attributes.contentDescription = [
                item.pronunciation,
                item.meaning
            ]
            .compactMap { $0 }
            .joined(separator: " — ")
            attributes.keywords = [item.term, item.language.title] + item.tags

            return CSSearchableItem(
                uniqueIdentifier: "voca://vocabulary/word/\(item.id)",
                domainIdentifier: spotlightDomainIdentifier,
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { _ in }
    }

    static func clearSpotlightIndex() {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [spotlightDomainIdentifier]
        ) { _ in }
    }

    static func scheduleDailyReviewReminderIfAuthorized(dueCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                return
            }

            let identifier = "site.thaonv.voca.macos.daily-review-reminder"
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            guard dueCount > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = "Đã đến giờ ôn tập Voca"
            content.body = "Bạn có \(dueCount) thẻ từ vựng sẵn sàng ôn tập hôm nay."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func requestNotificationPermissionAndSchedule(dueCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            scheduleDailyReviewReminderIfAuthorized(dueCount: dueCount)
        }
    }

    static func clearNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

// MARK: - Shortcuts & Automation Bridge

@MainActor
enum MacShortcutsBridge {
    static func handleDueCountSummary(today: MacTodayStore) -> String {
        let due = today.snapshot.dueCount
        let goal = today.snapshot.dailyGoal
        let completed = today.snapshot.completedGoalCount
        return "\(due) due · \(completed)/\(goal) daily goal completed"
    }
}
