import AppKit
import Carbon
import SwiftUI

/// Manages the global floating `NSPanel` for Quick Lookup and registers a
/// system-wide hotkey (`Option + Space`) plus standard macOS Services menu
/// (`Look Up in Voca`, `Add to Voca`) via `NSApp.servicesProvider`.
@MainActor
final class MacQuickLookupPanelController: NSObject {
    static let shared = MacQuickLookupPanelController()

    private var panel: MacFloatingLookupPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var currentHotKeyPreset: MacPreferencesStore.QuickLookupHotkey = .optionSpace
    private var previousApp: NSRunningApplication?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var openMainWorkspaceHandler: (() -> Void)?

    private weak var router: MacAppRouter?
    private weak var vocabulary: MacVocabularyStore?
    private weak var speech: MacSpeechService?
    private weak var preferences: MacPreferencesStore?

    private override init() {
        super.init()
    }

    func configure(
        router: MacAppRouter,
        vocabulary: MacVocabularyStore,
        speech: MacSpeechService,
        preferences: MacPreferencesStore? = nil,
        openMainWorkspace: (() -> Void)? = nil
    ) {
        self.router = router
        self.vocabulary = vocabulary
        self.speech = speech
        if let preferences {
            self.preferences = preferences
            self.currentHotKeyPreset = preferences.quickLookupHotkey
        }
        if let openMainWorkspace {
            self.openMainWorkspaceHandler = openMainWorkspace
        }

        NSApp?.servicesProvider = self
        registerGlobalHotKey(preset: currentHotKeyPreset)
    }

    func applyHotKeyPreference(
        _ preset: MacPreferencesStore.QuickLookupHotkey
    ) {
        currentHotKeyPreset = preset
        guard router != nil else { return }
        registerGlobalHotKey(preset: preset)
    }

    func toggleFloatingPanel(initialQuery: String? = nil) {
        if let panel, panel.isVisible {
            if let initialQuery, !initialQuery.isEmpty {
                showFloatingPanel(initialQuery: initialQuery)
            } else {
                dismissFloatingPanel()
            }
        } else {
            showFloatingPanel(initialQuery: initialQuery)
        }
    }

    func showFloatingPanel(initialQuery: String? = nil) {
        guard let router, let vocabulary, let speech else { return }

        MacSystemIntegrations.dismissMenuBarPopoverIfNeeded()

        if panel?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        let targetPanel: MacFloatingLookupPanel
        if let existing = panel {
            targetPanel = existing
        } else {
            let created = MacFloatingLookupPanel(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
                styleMask: [
                    .titled,
                    .closable,
                    .fullSizeContentView,
                    .nonactivatingPanel
                ],
                backing: .buffered,
                defer: false
            )
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.isFloatingPanel = true
            created.hidesOnDeactivate = false
            created.becomesKeyOnlyIfNeeded = false
            created.level = .statusBar
            created.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .transient,
                .ignoresCycle
            ]
            created.isMovableByWindowBackground = true
            created.standardWindowButton(.closeButton)?.isHidden = true
            created.standardWindowButton(.miniaturizeButton)?.isHidden = true
            created.standardWindowButton(.zoomButton)?.isHidden = true
            created.isOpaque = false
            created.backgroundColor = .clear
            created.hasShadow = true
            created.delegate = self
            panel = created
            targetPanel = created
        }

        let colorScheme: ColorScheme? = {
            switch preferences?.appearance {
            case .light:
                return .light
            case .dark:
                return .dark
            default:
                return nil
            }
        }()

        let rootView = MacQuickLookupPanelRootView(
            initialQuery: initialQuery,
            onDismiss: { [weak self] in
                self?.dismissFloatingPanel()
            },
            onOpenWordDetail: { [weak self] wordID in
                guard let self else { return }
                self.dismissFloatingPanel(restorePreviousApp: false)
                self.router?.open(.vocabularyWord(id: wordID))
                self.openMainWorkspaceHandler?()
                if self.findActiveVocaMainWindow() == nil,
                   let encoded = wordID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "voca://vocabulary/word/\(encoded)") {
                    NSWorkspace.shared.open(url)
                }
                MacSystemIntegrations.bringMainWindowsToFront()
            }
        )
        .environment(router)
        .environment(vocabulary)
        .environment(speech)
        .tint(VocaDesign.brandGreen)
        .preferredColorScheme(colorScheme)

        targetPanel.contentView = NSHostingView(rootView: rootView)
        positionPanel(targetPanel)
        installOutsideClickMonitors()
        targetPanel.makeKeyAndOrderFront(nil)
        targetPanel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            targetPanel.makeKey()
        }
    }

    func dismissFloatingPanel(restorePreviousApp: Bool = true) {
        removeOutsideClickMonitors()
        panel?.orderOut(nil)
        if restorePreviousApp,
           let previousApp,
           previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }
        previousApp = nil
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        // Dismiss when user clicks outside in another application
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismissFloatingPanel()
            }
        }

        // Dismiss when user clicks outside the panel within our own application
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            let clickLocation = NSEvent.mouseLocation
            if !NSPointInRect(clickLocation, panel.frame) {
                self.dismissFloatingPanel()
            }
            return event
        }
    }

    private func removeOutsideClickMonitors() {
        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
    }

    // MARK: - macOS System Services (`NSServices`)

    @objc func lookUpInVoca(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return
        }
        showFloatingPanel(initialQuery: String(text.prefix(120)))
    }

    @objc func addToVoca(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return
        }
        router?.select(.vocabulary)
        router?.requestAddWord(initialTerm: String(text.prefix(80)))
        openMainWorkspaceHandler?()
        MacSystemIntegrations.bringMainWindowsToFront()
    }

    // MARK: - Configurable Global Hotkey

    private func registerGlobalHotKey(
        preset: MacPreferencesStore.QuickLookupHotkey
    ) {
        if let existingHotKey = hotKeyRef {
            UnregisterEventHotKey(existingHotKey)
            hotKeyRef = nil
        }

        guard preset != .disabled else {
            return
        }

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, _ -> OSStatus in
                    Task { @MainActor in
                        MacQuickLookupPanelController.shared.toggleFloatingPanel()
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                &eventHandlerRef
            )

            guard status == noErr else { return }
        }

        let modifiers: UInt32
        switch preset {
        case .optionSpace:
            modifiers = UInt32(optionKey)
        case .commandShiftSpace:
            modifiers = UInt32(cmdKey | shiftKey)
        case .controlOptionSpace:
            modifiers = UInt32(controlKey | optionKey)
        case .disabled:
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x564F_4341), // 'VOCA'
            id: 1
        )

        RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func positionPanel(_ window: NSPanel) {
        if NSApp.isActive,
           let mainWindow = findActiveVocaMainWindow(),
           mainWindow.isOnActiveSpace {
            let mainFrame = mainWindow.frame
            let size = window.frame.size
            let x = mainFrame.midX - (size.width / 2)
            let y = mainFrame.midY - (size.height / 2) + 24
            window.setFrameOrigin(
                NSPoint(
                    x: max(mainFrame.minX + 16, min(x, mainFrame.maxX - size.width - 16)),
                    y: max(mainFrame.minY + 16, min(y, mainFrame.maxY - size.height - 16))
                )
            )
            return
        }

        positionPanelOnActiveScreen(window)
    }

    private func findActiveVocaMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.isVisible &&
            !window.isMiniaturized &&
            !window.isFloatingPanel &&
            window !== panel &&
            !(window.className.contains("StatusBar") || window.className.contains("Menu")) &&
            window.frame.width >= 400 &&
            window.frame.height >= 300
        }
    }

    private func positionPanelOnActiveScreen(_ window: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let size = window.frame.size
        let x = visibleFrame.midX - (size.width / 2)
        let y = visibleFrame.minY + (visibleFrame.height * 0.58) - (size.height / 2)
        window.setFrameOrigin(
            NSPoint(
                x: max(visibleFrame.minX + 16, min(x, visibleFrame.maxX - size.width - 16)),
                y: max(visibleFrame.minY + 16, min(y, visibleFrame.maxY - size.height - 16))
            )
        )
    }
}

extension MacQuickLookupPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        dismissFloatingPanel()
    }
}

final class MacFloatingLookupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        MacQuickLookupPanelController.shared.dismissFloatingPanel()
    }
}

struct MacQuickLookupPanelRootView: View {
    let initialQuery: String?
    let onDismiss: () -> Void
    let onOpenWordDetail: (String) -> Void

    var body: some View {
        MacQuickLookupView(
            initialQuery: initialQuery,
            onDismiss: onDismiss,
            onOpenWordDetail: onOpenWordDetail
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 24, y: 10)
    }
}
