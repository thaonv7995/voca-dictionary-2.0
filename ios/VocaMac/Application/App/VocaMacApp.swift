import AppKit
import CoreSpotlight
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>
extension StudyService: @unchecked Sendable {}
extension CardsService: @unchecked Sendable {}

@main
struct VocaMacApp: App {
    @ViewState private var router: MacAppRouter
    @ViewState private var session: MacSessionStore
    @ViewState private var preferences: MacPreferencesStore
    @ViewState private var ledger: MacActivityLedger
    @ViewState private var vocabulary: MacVocabularyStore
    @ViewState private var review: MacReviewStore
    @ViewState private var today: MacTodayStore
    @ViewState private var speech: MacSpeechService

    init() {
        VocaDesign.ensureChineseFontsRegistered()
        let activityLedger = MacActivityLedger()
        let initialRouter = MacAppRouter()
        let initialSession = MacSessionStore()
        let initialPreferences = MacPreferencesStore()
        let initialVocabulary = MacVocabularyStore(ledger: activityLedger)
        let initialReview = MacReviewStore(ledger: activityLedger)
        let initialToday = MacTodayStore(ledger: activityLedger)
        let initialSpeech = MacSpeechService()

        initialSession.onDidSignOut = {
            initialSpeech.stop()
            MacQuickLookupPanelController.shared.dismissFloatingPanel()
            activityLedger.resetInMemoryState()
            initialVocabulary.resetForSignOut()
            initialReview.resetForSignOut()
            initialToday.resetForSignOut(dailyGoal: initialPreferences.dailyGoal)
        }

        _router = State(initialValue: initialRouter)
        _session = State(initialValue: initialSession)
        _preferences = State(initialValue: initialPreferences)
        _ledger = State(initialValue: activityLedger)
        _vocabulary = State(initialValue: initialVocabulary)
        _review = State(initialValue: initialReview)
        _today = State(initialValue: initialToday)
        _speech = State(initialValue: initialSpeech)

        Task { @MainActor in
            MacQuickLookupPanelController.shared.configure(
                router: initialRouter,
                session: initialSession,
                vocabulary: initialVocabulary,
                speech: initialSpeech,
                preferences: initialPreferences
            )
            await initialSession.bootstrap()
            if initialSession.isSignedIn {
                activityLedger.reloadForCurrentAccount()
                async let todayTask: Void = initialToday.load(
                    dailyGoal: initialPreferences.dailyGoal
                )
                async let reviewTask: Void = initialReview.load()
                async let vocabTask: Void = initialVocabulary.load()
                _ = await (todayTask, reviewTask, vocabTask)
            }
        }
    }

    private var menuBarSelection: Binding<Bool> {
        Binding(
            get: { preferences.showInMenuBar },
            set: { preferences.setShowInMenuBar($0) }
        )
    }

    private var menuBarDueCount: Int {
        max(today.snapshot.dueCount, review.cards.count)
    }

    var body: some Scene {
        WindowGroup(id: "main-workspace") {
            MacRootView()
                .environment(router)
                .environment(session)
                .environment(preferences)
                .environment(ledger)
                .environment(vocabulary)
                .environment(review)
                .environment(today)
                .environment(speech)
                .tint(VocaDesign.brandGreen)
                .preferredColorScheme(preferredColorScheme)
                .frame(minWidth: 640, minHeight: 500)
                .onOpenURL { url in
                    router.open(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let identifier = activity.userInfo?[
                        CSSearchableItemActivityIdentifier
                    ] as? String,
                       let url = URL(string: identifier) {
                        router.open(url)
                    }
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Điều hướng") {
                ForEach(Array(MacDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                    Button(destination.title) {
                        router.select(destination)
                        MacSystemIntegrations.bringMainWindowsToFront()
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                }
            }

            CommandMenu("Học tập") {
                Button("Bắt đầu ôn tập ngay") {
                    router.select(.review)
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Luyện tập trắc nghiệm & kỹ năng") {
                    router.select(.practice)
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Hỏi Gia sư AI") {
                    router.select(.assistant)
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Button("Thêm từ mới bằng AI…") {
                    router.requestAddWord()
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Tra nhanh trong ứng dụng") {
                    router.open(.quickLookup(query: nil))
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Bảng tra từ nổi toàn hệ thống") {
                    MacQuickLookupPanelController.shared.toggleFloatingPanel()
                }
                .keyboardShortcut(.space, modifiers: .option)

                Divider()

                Button("Nhập từ vựng / Quét OCR…") {
                    router.requestImportExport(mode: .importWords)
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Xuất từ vựng…") {
                    router.requestImportExport(mode: .exportWords)
                    MacSystemIntegrations.bringMainWindowsToFront()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Window("Phòng ôn tập tập trung", id: "review-focus") {
            MacReviewView(isFocusWindow: true)
                .environment(router)
                .environment(session)
                .environment(preferences)
                .environment(ledger)
                .environment(vocabulary)
                .environment(review)
                .environment(today)
                .environment(speech)
                .tint(VocaDesign.brandGreen)
                .preferredColorScheme(preferredColorScheme)
                .frame(minWidth: 520, minHeight: 460)
        }
        .defaultSize(width: 820, height: 620)

        MenuBarExtra(isInserted: menuBarSelection) {
            MacMenuBarView()
                .environment(router)
                .environment(session)
                .environment(preferences)
                .environment(ledger)
                .environment(vocabulary)
                .environment(review)
                .environment(today)
                .environment(speech)
                .tint(VocaDesign.brandGreen)
                .preferredColorScheme(preferredColorScheme)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: VocaDesign.menuBarStatusImage)
                if session.isSignedIn && menuBarDueCount > 0 {
                    switch preferences.menuBarBadgeStyle {
                    case .dueCount:
                        Text(menuBarDueCount > 99 ? "99+" : "\(menuBarDueCount)")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                    case .dotOnly:
                        Text("•")
                            .font(.system(size: 12, weight: .black))
                    case .iconOnly:
                        EmptyView()
                    }
                }
            }
            .accessibilityLabel(
                menuBarDueCount > 0
                    ? "Voca, \(menuBarDueCount) thẻ cần ôn tập"
                    : "Voca"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            MacSettingsView()
                .environment(session)
                .environment(preferences)
                .environment(speech)
                .tint(VocaDesign.brandGreen)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch preferences.appearance {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

private struct MacRootView: View {
    @Environment(MacAppRouter.self) private var router
    @Environment(MacSessionStore.self) private var session
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacActivityLedger.self) private var ledger
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacReviewStore.self) private var review
    @Environment(MacTodayStore.self) private var today
    @Environment(MacSpeechService.self) private var speech
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Đang khởi động Voca…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await session.bootstrap()
                }

            case .signedOut:
                MacLoginView()

            case .signedIn:
                MacWorkspaceView()
            }
        }
        .onAppear {
            MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: preferences.hideDockIcon)
            MacSystemIntegrations.updateLaunchAtLogin(enabled: preferences.launchAtLogin)
            MacQuickLookupPanelController.shared.configure(
                router: router,
                session: session,
                vocabulary: vocabulary,
                speech: speech,
                preferences: preferences,
                openMainWorkspace: {
                    openWindow(id: "main-workspace")
                }
            )
        }
        .onChange(of: session.phase) { _, newPhase in
            guard case .signedIn = newPhase else { return }
            ledger.reloadForCurrentAccount()
            Task {
                async let todayTask: Void = today.load(dailyGoal: preferences.dailyGoal)
                async let reviewTask: Void = review.load()
                async let vocabTask: Void = vocabulary.load()
                _ = await (todayTask, reviewTask, vocabTask)
            }
        }
    }
}

private struct MacLoginView: View {
    @Environment(MacSessionStore.self) private var session

    @ViewState private var email = ""
    @ViewState private var password = ""
    @ViewState private var rememberCredentials = true
    @ViewState private var showServerSheet = false
    @ViewState private var showRegisterSheet = false
    @ViewState private var serverOnline: Bool?
    @ViewState private var currentServerURLString = AppConfig.baseURL.absoluteString
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var currentServerDisplay: String {
        if let url = URL(string: currentServerURLString), let host = url.host {
            if let port = url.port {
                return "\(host):\(port)"
            }
            return host
        }
        return currentServerURLString
    }

    private var statusText: String {
        switch serverOnline {
        case .some(true):
            return "Máy chủ trực tuyến · \(currentServerURLString)"
        case .some(false):
            return "Không kết nối được \(currentServerURLString)"
        case .none:
            return "Đang kiểm tra kết nối…"
        }
    }

    var body: some View {
        ZStack {
            VocaDesign.subtleWindowBackground

            VStack(spacing: 20) {
                // Elevated Login Card
                VStack(spacing: 24) {
                    // Brand Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(VocaDesign.brandGreen.opacity(0.15))
                                .frame(width: 78, height: 78)
                                .blur(radius: 12)

                            VocaBrandMark(size: 64)
                        }
                        .accessibilityHidden(true)

                        VStack(spacing: 6) {
                            Text("Welcome to Voca")
                                .font(.system(size: 30, weight: .bold, design: .rounded))

                            Text("Đăng nhập để đồng bộ từ vựng & lịch ôn tập trên Mac")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Credentials Section
                    VStack(alignment: .leading, spacing: 12) {
                        VocaInputField(
                            icon: "envelope.fill",
                            placeholder: "Địa chỉ Email",
                            text: $email,
                            isFocused: focusedField == .email,
                            onSubmit: {
                                focusedField = .password
                            }
                        )
                        .focused($focusedField, equals: .email)

                        VocaInputField(
                            icon: "lock.fill",
                            placeholder: "Mật khẩu",
                            text: $password,
                            isSecure: true,
                            isFocused: focusedField == .password,
                            onSubmit: {
                                signIn()
                            }
                        )
                        .focused($focusedField, equals: .password)

                        HStack {
                            Toggle("Lưu thông tin đăng nhập", isOn: $rememberCredentials)
                                .toggleStyle(.checkbox)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if session.savedCredentials != nil {
                                Button("Xóa đã lưu") {
                                    session.clearSavedCredentials()
                                    email = ""
                                    password = ""
                                    rememberCredentials = false
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VocaDesign.accentRose)
                            }
                        }
                        .padding(.top, 2)
                    }

                    if let error = session.signInError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(VocaDesign.accentRose)
                            Text(error.localizedDescription)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(VocaDesign.accentRose)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(VocaDesign.accentRose.opacity(0.10))
                        )
                    }

                    // Primary Sign In Action
                    VStack(spacing: 12) {
                        Button(action: signIn) {
                            HStack(spacing: 8) {
                                if session.isSigningIn {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(session.isSigningIn ? "Đang đăng nhập…" : "Đăng nhập")
                            }
                        }
                        .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                        .disabled(session.isSigningIn)
                        .keyboardShortcut(.return, modifiers: .command)

                        Button("Chưa có tài khoản? Đăng ký") {
                            showRegisterSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(VocaDesign.brandGreen)
                    }

                    Divider()
                        .opacity(0.6)

                    // Backend Server Selector Card (matching iOS LoginView)
                    Button {
                        showServerSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            VocaIconBadge(
                                systemImage: "server.rack",
                                tint: serverOnline == false ? VocaDesign.accentRose : VocaDesign.brandGreen,
                                size: 36,
                                iconSize: 15
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Máy chủ kết nối")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(currentServerDisplay)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(
                                        serverOnline == nil
                                            ? Color.gray
                                            : (serverOnline == true ? VocaDesign.brandGreen : VocaDesign.accentRose)
                                    )
                                    .frame(width: 8, height: 8)

                                Text(
                                    serverOnline == nil
                                        ? "Đang kiểm tra"
                                        : (serverOnline == true ? "Trực tuyến" : "Mất kết nối")
                                )
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Color.primary.opacity(0.05),
                                in: Capsule()
                            )
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.65))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
                .frame(width: 440)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Connection status pill badge at bottom
                Button {
                    showServerSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                serverOnline == nil
                                    ? Color.gray
                                    : (serverOnline == true ? VocaDesign.brandGreen : VocaDesign.accentRose)
                            )
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let saved = session.savedCredentials {
                email = saved.email
                password = saved.password
                rememberCredentials = saved.rememberCredentials
            }
            focusedField = email.isEmpty ? .email : .password
            refreshHealth()
        }
        .onChange(of: email) { _, _ in
            session.dismissSignInError()
        }
        .sheet(isPresented: $showServerSheet) {
            MacServerConfigSheet {
                currentServerURLString = AppConfig.baseURL.absoluteString
                refreshHealth()
            }
        }
        .sheet(isPresented: $showRegisterSheet) {
            MacRegisterSheet(rememberCredentials: rememberCredentials)
                .environment(session)
        }
    }

    private func refreshHealth() {
        currentServerURLString = AppConfig.baseURL.absoluteString
        Task {
            serverOnline = nil
            let online = await ApiClient.shared.health()
            await MainActor.run {
                serverOnline = online
            }
        }
    }

    private func signIn() {
        focusedField = nil

        Task {
            await session.signIn(
                email: email,
                password: password,
                rememberCredentials: rememberCredentials
            )
        }
    }
}

private struct MacServerConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    @ViewState private var serverUrl: String = AppConfig.baseURL.absoluteString
    @ViewState private var isTesting = false
    @ViewState private var testResult: (ok: Bool, message: String)?
    @ViewState private var errorMessage: String?

    private struct PresetItem: Identifiable {
        let id: String
        let name: String
        let description: String
        let url: String
    }

    private var presets: [PresetItem] {
        [
            PresetItem(
                id: "prod",
                name: "Chính thức (Production)",
                description: "Máy chủ trực tuyến đám mây",
                url: AppConfig.productionURL.absoluteString
            ),
            PresetItem(
                id: "local",
                name: "Máy ảo / Localhost (Simulator)",
                description: "Backend chạy trên cổng 22052",
                url: AppConfig.simulatorURL.absoluteString
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VocaIconBadge(
                    systemImage: "server.rack",
                    tint: VocaDesign.brandGreen,
                    size: 38,
                    iconSize: 17
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cài đặt máy chủ")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Chọn máy chủ Voca Backend hoặc nhập địa chỉ tùy chỉnh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Đóng") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ĐỊA CHỈ MÁY CHỦ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    VocaInputField(
                        icon: "link",
                        placeholder: "http:// hoặc https://...",
                        text: $serverUrl,
                        onSubmit: {
                            testCurrent()
                        }
                    )

                    Button {
                        testCurrent()
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("Kiểm tra")
                        }
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                    .disabled(isTesting || serverUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Text("Hỗ trợ http:// và https://. Tự động kiểm tra probe GET /v1/health.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let testResult {
                    HStack(alignment: .center, spacing: 8) {
                        Image(
                            systemName: testResult.ok
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(testResult.ok ? VocaDesign.brandGreen : VocaDesign.accentRose)
                        Text(testResult.message)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(testResult.ok ? VocaDesign.brandGreen : VocaDesign.accentRose)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((testResult.ok ? VocaDesign.brandGreen : VocaDesign.accentRose).opacity(0.10))
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(VocaDesign.accentRose)
                }
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 8) {
                Text("MÁY CHỦ GỢI Ý")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                ForEach(presets) { preset in
                    let active = isSelected(preset.url)
                    Button {
                        serverUrl = preset.url
                        testCurrent()
                    } label: {
                        HStack(spacing: 12) {
                            VocaIconBadge(
                                systemImage: preset.id == "prod" ? "cloud.fill" : "desktopcomputer",
                                tint: active ? VocaDesign.brandGreen : .secondary,
                                size: 32,
                                iconSize: 14
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(preset.description) · \(preset.url)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if active {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(VocaDesign.brandGreen)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    active
                                        ? VocaDesign.brandGreen.opacity(0.10)
                                        : Color(nsColor: .controlBackgroundColor)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    active
                                        ? VocaDesign.brandGreen.opacity(0.45)
                                        : Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.6)

            HStack {
                Button {
                    resetToDefault()
                } label: {
                    Label("Khôi phục mặc định", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(VocaSecondaryButtonStyle(tint: VocaDesign.accentRose))

                Spacer()

                Button("Hủy") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button("Lưu thiết lập") {
                    save()
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .disabled(serverUrl.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear {
            serverUrl = AppConfig.baseURL.absoluteString
        }
    }

    private func isSelected(_ candidate: String) -> Bool {
        let norm1 = (try? AppConfig.normalizeAndValidate(url: candidate))?.absoluteString
        let norm2 = (try? AppConfig.normalizeAndValidate(url: serverUrl))?.absoluteString
        return norm1 != nil && norm1 == norm2
    }

    private func testCurrent() {
        isTesting = true
        testResult = nil
        errorMessage = nil
        let target = serverUrl
        Task {
            let res = await ApiClient.shared.checkHealth(for: target)
            await MainActor.run {
                testResult = res
                isTesting = false
            }
        }
    }

    private func save() {
        errorMessage = nil
        do {
            try AppConfig.setCustomURL(serverUrl)
            Task {
                await ApiClient.shared.clearTokens()
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resetToDefault() {
        AppConfig.resetToDefault()
        Task {
            await ApiClient.shared.clearTokens()
        }
        serverUrl = AppConfig.defaultBaseURL.absoluteString
        testResult = nil
        errorMessage = nil
        testCurrent()
    }
}

private struct MacRegisterSheet: View {
    @Environment(MacSessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let rememberCredentials: Bool

    @ViewState private var email = ""
    @ViewState private var displayName = ""
    @ViewState private var password = ""
    @ViewState private var confirmPassword = ""
    @ViewState private var errorMessage: String?
    @ViewState private var isBusy = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var canSubmit: Bool {
        !isBusy
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && passwordsMatch
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VocaIconBadge(
                    systemImage: "person.badge.plus",
                    tint: VocaDesign.brandGreen,
                    size: 38,
                    iconSize: 17
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đăng ký tài khoản")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Tạo tài khoản mới để đồng bộ từ vựng giữa Web, iOS và macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Đóng") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                VocaInputField(
                    icon: "envelope.fill",
                    placeholder: "Địa chỉ Email",
                    text: $email
                )
                VocaInputField(
                    icon: "person.fill",
                    placeholder: "Tên hiển thị (tùy chọn)",
                    text: $displayName
                )
                VocaInputField(
                    icon: "lock.fill",
                    placeholder: "Mật khẩu (tối thiểu 6 ký tự)",
                    text: $password,
                    isSecure: true
                )
                VocaInputField(
                    icon: "checkmark.shield.fill",
                    placeholder: "Nhập lại mật khẩu",
                    text: $confirmPassword,
                    isSecure: true,
                    onSubmit: {
                        if canSubmit {
                            submit()
                        }
                    }
                )

                if !confirmPassword.isEmpty && !passwordsMatch {
                    Label("Mật khẩu nhập lại không khớp.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(VocaDesign.accentRose)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(VocaDesign.accentRose)
                }
            }

            HStack {
                Spacer()
                Button("Hủy") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button {
                    submit()
                } label: {
                    HStack(spacing: 6) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Tạo tài khoản")
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func submit() {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await session.register(
                    email: email,
                    password: password,
                    displayName: displayName,
                    rememberCredentials: rememberCredentials
                )
                dismiss()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isBusy = false
        }
    }
}

private struct MacWorkspaceView: View {
    @Environment(MacAppRouter.self) private var router
    @Environment(MacSessionStore.self) private var session
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacTodayStore.self) private var today
    @Environment(MacReviewStore.self) private var review
    @Environment(\.openSettings) private var openSettings
    @ViewState private var hasAppliedDefaultDestination = false
    @ViewState private var isShortcutsSheetPresented = false

    private var selection: Binding<MacDestination?> {
        Binding(
            get: { router.selectedDestination },
            set: { destination in
                guard let destination else { return }
                router.select(destination)
            }
        )
    }

    private func destinationTint(_ destination: MacDestination) -> Color {
        switch destination {
        case .today:
            return VocaDesign.brandGreen
        case .vocabulary:
            return VocaDesign.accentSky
        case .review:
            return VocaDesign.accentIndigo
        case .practice:
            return VocaDesign.accentAmber
        case .assistant:
            return VocaDesign.brandTeal
        case .insights:
            return VocaDesign.accentRose
        }
    }

    var body: some View {
        NavigationSplitView {
            List(MacDestination.allCases, selection: selection) { destination in
                let index = (MacDestination.allCases.firstIndex(of: destination) ?? 0) + 1
                HStack(spacing: 10) {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(destinationTint(destination))
                        .frame(width: 26, height: 26)
                        .background(
                            destinationTint(destination).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )

                    Text(destination.title)
                        .font(.body.weight(.medium))

                    Spacer()

                    if destination == .review {
                        let dueCount = max(today.snapshot.dueCount, review.cards.count)
                        if dueCount > 0 {
                            Text("\(dueCount)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    VocaDesign.accentIndigo,
                                    in: Capsule()
                                )
                        } else {
                            Text("⌘\(index)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    } else if destination == .vocabulary, !vocabulary.items.isEmpty {
                        Text("\(vocabulary.items.count)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    } else {
                        Text("⌘\(index)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 3)
                .tag(destination)
            }
            .safeAreaInset(edge: .top) {
                sidebarBrandHeader
            }
            .safeAreaInset(edge: .bottom) {
                accountFooter
            }
            .navigationTitle("Voca")
            .navigationSplitViewColumnWidth(min: 220, ideal: 244, max: 280)
        } detail: {
            destinationView
                .id(router.selectedDestination)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
                .animation(.snappy(duration: 0.2), value: router.selectedDestination)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isShortcutsSheetPresented = true
                } label: {
                    Label("Phím tắt", systemImage: "keyboard")
                }
                .keyboardShortcut("/", modifiers: .command)
                .help("Phím tắt toàn hệ thống (⌘/)")

                Button {
                    router.open(.quickLookup(query: nil))
                } label: {
                    Label("Tra nhanh", systemImage: "magnifyingglass")
                }
                .help("Tra nhanh từ vựng (\(preferences.quickLookupHotkey.badgeLabel) / ⇧⌘K)")

                Button {
                    router.requestImportExport(mode: .importWords)
                } label: {
                    Label("Nhập / Xuất", systemImage: "square.and.arrow.down")
                }
                .help("Nhập / Xuất từ vựng & Quét OCR (⇧⌘I)")

                Button {
                    router.requestAddWord()
                } label: {
                    Label("Thêm từ", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Thêm từ mới bằng AI (⌘N)")
            }
        }
        .sheet(isPresented: $isShortcutsSheetPresented) {
            MacShortcutCheatsheetSheet()
        }
        .sheet(
            isPresented: Binding(
                get: { router.isQuickLookupPresented },
                set: { isPresented in
                    if !isPresented {
                        router.dismissQuickLookup()
                    }
                }
            )
        ) {
            MacQuickLookupView(
                initialQuery: router.quickLookupQuery,
                onDismiss: router.dismissQuickLookup,
                onOpenWordDetail: { wordID in
                    router.dismissQuickLookup()
                    router.open(.vocabularyWord(id: wordID))
                }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { router.isAddWordPresented },
                set: { isPresented in
                    if !isPresented {
                        router.dismissAddWord()
                    }
                }
            )
        ) {
            MacAddWordSheet(
                initialWord: router.addWordInitialTerm ?? "",
                onCreated: { created in
                    router.dismissAddWord()
                    router.open(.vocabularyWord(id: created.id))
                }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { router.isImportExportPresented },
                set: { isPresented in
                    if !isPresented {
                        router.dismissImportExport()
                    }
                }
            )
        ) {
            MacImportExportSheet(
                initialMode: router.importExportInitialMode,
                initialText: router.importExportInitialText
            )
        }
        .alert(
            "Không thể mở liên kết",
            isPresented: Binding(
                get: { router.routeError != nil },
                set: { isPresented in
                    if !isPresented {
                        router.dismissRouteError()
                    }
                }
            ),
            presenting: router.routeError
        ) { _ in
            Button("Đóng") {
                router.dismissRouteError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: router.isSettingsRequested) { _, isRequested in
            guard isRequested else { return }
            openSettings()
            router.consumeSettingsRequest()
        }
        .onAppear {
            guard !hasAppliedDefaultDestination else {
                return
            }

            hasAppliedDefaultDestination = true
            router.select(preferences.defaultDestination.destination)
        }
    }

    private var sidebarBrandHeader: some View {
        HStack(spacing: 10) {
            VocaBrandMark(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Voca Dictionary")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Circle()
                        .fill(
                            vocabulary.pendingMutationCount > 0
                                ? VocaDesign.accentAmber
                                : VocaDesign.brandGreen
                        )
                        .frame(width: 6, height: 6)
                    Text(
                        vocabulary.isLoading
                            ? "Đang đồng bộ…"
                            : (vocabulary.pendingMutationCount > 0
                                ? "\(vocabulary.pendingMutationCount) chờ đồng bộ"
                                : "Đã đồng bộ Cloud")
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                router.open(.quickLookup(query: nil))
            } label: {
                Text(preferences.quickLookupHotkey.badgeLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Mở Tra nhanh (\(preferences.quickLookupHotkey.badgeLabel))")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private var accountFooter: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(VocaDesign.brandGradient)
                    .frame(width: 34, height: 34)
                Text(
                    String((session.account?.displayName ?? "V").prefix(1)).uppercased()
                )
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.account?.displayName ?? "Voca Learner")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(session.account?.email ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Nhập từ vựng / Quét OCR… (⇧⌘I)") {
                    router.requestImportExport(mode: .importWords)
                }

                Button("Xuất từ vựng… (⇧⌘E)") {
                    router.requestImportExport(mode: .exportWords)
                }

                Divider()

                Button("Bảng phím tắt… (⌘/)") {
                    isShortcutsSheetPresented = true
                }

                Button("Cài đặt… (⌘,)") {
                    openSettings()
                }

                Divider()

                Button("Đăng xuất", role: .destructive) {
                    session.signOut()
                    router.select(.today)
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Menu tài khoản")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch router.selectedDestination {
        case .today:
            MacTodayView(
                startReview: {
                    router.select(.review)
                },
                openVocabulary: {
                    router.select(.vocabulary)
                },
                startPractice: {
                    router.select(.practice)
                }
            )
        case .vocabulary:
            MacVocabularyView(
                requestedItemID: router.selectedVocabularyWordID,
                addWord: {
                    router.requestAddWord()
                },
                onDropTextOrFile: { droppedText in
                    router.requestImportExport(
                        mode: .importWords,
                        initialText: droppedText
                    )
                }
            )
        case .review:
            MacReviewView(
                closeReview: {
                    router.select(.today)
                }
            )
        case .practice:
            MacPracticeView(
                closePractice: {
                    router.select(.today)
                }
            )
        case .assistant:
            MacAssistantView()
        case .insights:
            MacInsightsView(
                reviewDifficultWords: {
                    router.select(.review)
                },
                startPractice: {
                    router.select(.practice)
                }
            )
        }
    }
}

struct MacQuickLookupView: View {
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech

    @ViewState private var query: String
    @ViewState private var selectedLanguage: MacVocabularyItem.Language = .english
    @ViewState private var selectedItemID: MacVocabularyItem.ID?
    @ViewState private var clipboardCandidate: String?
    @ViewState private var isCreatingWithAI = false
    @ViewState private var creationError: String?
    @ViewState private var toastState: (icon: String, message: String, tint: Color)?
    @FocusState private var isSearchFocused: Bool

    let onDismiss: () -> Void
    let onOpenWordDetail: (String) -> Void

    init(
        initialQuery: String?,
        onDismiss: @escaping () -> Void,
        onOpenWordDetail: @escaping (String) -> Void = { _ in }
    ) {
        let q = initialQuery ?? ""
        _query = State(initialValue: q)
        _selectedLanguage = State(
            initialValue: VocaDesign.containsHanCharacters(q) ? .chinese : .english
        )
        self.onDismiss = onDismiss
        self.onOpenWordDetail = onOpenWordDetail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchHeaderBar

            Divider().opacity(0.6)

            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.55)

            shortcutFooterBar
        }
        .background(VocaDesign.subtleWindowBackground)
        .frame(minWidth: 660, idealWidth: 680, minHeight: 420, idealHeight: 440)
        .overlay(alignment: .bottom) {
            if let toastState {
                VocaToastBanner(
                    icon: toastState.icon,
                    message: toastState.message,
                    tint: toastState.tint
                )
                .padding(.bottom, 42)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            lookupKeyboardShortcuts
        }
        .onAppear {
            syncSelectedItem()
            inspectClipboardSuggestion()
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .task {
            await vocabulary.load()
            syncSelectedItem()
            try? await Task.sleep(nanoseconds: 50_000_000)
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notif in
            if let window = notif.object as? NSWindow, window === NSApp.keyWindow {
                inspectClipboardSuggestion()
                isSearchFocused = true
            }
        }
        .onChange(of: query) { _, newQuery in
            creationError = nil
            if VocaDesign.containsHanCharacters(newQuery), selectedLanguage != .chinese {
                withAnimation(.snappy(duration: 0.18)) {
                    selectedLanguage = .chinese
                }
            }
            syncSelectedItem()
        }
        .onChange(of: vocabulary.items) { _, _ in
            syncSelectedItem()
        }
        .onChange(of: selectedLanguage) { _, _ in
            syncSelectedItem()
        }
    }

    // MARK: - Header

    private var searchHeaderBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VocaDesign.brandGreen)

            TextField("Tra từ Anh / Trung, Pinyin, nghĩa tiếng Việt hoặc tạo bằng AI…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16.5, weight: .medium, design: .rounded))
                .focused($isSearchFocused)
                .onSubmit {
                    submitPrimaryAction()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Xóa từ khóa (Esc)")
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    languageChip(language: .english, flag: "🇺🇸", label: "EN", tint: VocaDesign.accentSky, helpText: "Ưu tiên / Tạo bằng Tiếng Anh (⌘L / ⌘1)")
                    languageChip(language: .chinese, flag: "🇨🇳", label: "中文", tint: VocaDesign.accentAmber, helpText: "Ưu tiên / Tạo bằng Hán ngữ (⌘L / ⌘2)")
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

                Button(action: onDismiss) {
                    VocaKeycap(label: "ESC")
                }
                .buttonStyle(.plain)
                .help("Đóng cửa sổ tra nhanh (Esc)")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 13)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.86))
    }

    private func languageChip(
        language: MacVocabularyItem.Language,
        flag: String,
        label: String,
        tint: Color,
        helpText: String
    ) -> some View {
        let isSelected = selectedLanguage == language
        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedLanguage = language
            }
        } label: {
            HStack(spacing: 4) {
                Text(flag)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.11) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.55) : Color.clear, lineWidth: 1.1)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    // MARK: - Body

    @ViewBuilder
    private var mainContentArea: some View {
        if trimmedQuery.isEmpty {
            emptyPromptView
                .padding(18)
        } else if matchingItems.isEmpty {
            aiCreationEmptyView
                .padding(18)
        } else {
            splitResultsView
        }
    }

    private var emptyPromptView: some View {
        VStack(spacing: 16) {
            if let clipboardCandidate {
                HStack(spacing: 12) {
                    VocaIconBadge(
                        systemImage: "doc.on.clipboard.fill",
                        tint: VocaDesign.brandGreen,
                        size: 32,
                        iconSize: 14
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GỢI Ý TỪ BỘ NHỚ TẠM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("Tra nhanh “\(clipboardCandidate)”")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("Tra từ này") {
                        query = clipboardCandidate
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(VocaDesign.brandGreen.opacity(0.28), lineWidth: 1)
                )
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                VocaIconBadge(
                    systemImage: "sparkles",
                    tint: VocaDesign.brandGreen,
                    size: 46,
                    iconSize: 21
                )
                Text("Tra cứu đa ngôn ngữ & Tạo thẻ AI")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Tìm đồng thời cả Tiếng Anh và Hán ngữ theo từ vựng, Pinyin/IPA hoặc nghĩa tiếng Việt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Spacer(minLength: 0)
        }
    }

    private var aiCreationEmptyView: some View {
        VStack(spacing: 14) {
            if let creationError {
                errorBanner(creationError)
            }

            Spacer(minLength: 0)

            VocaIconBadge(
                systemImage: "sparkles",
                tint: VocaDesign.brandGreen,
                size: 48,
                iconSize: 22
            )

            Text("“\(trimmedQuery)” chưa có trong kho từ")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text("Tự động tạo thẻ từ hoàn chỉnh với phiên âm, giải nghĩa tiếng Việt, câu ví dụ và mẹo ghi nhớ bằng AI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button {
                    createWord(language: selectedLanguage)
                } label: {
                    HStack(spacing: 8) {
                        if isCreatingWithAI {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(
                            isCreatingWithAI
                                ? "Đang tạo bằng AI…"
                                : "Tạo thẻ \(selectedLanguage == .chinese ? "Hán ngữ" : "Tiếng Anh") (↩)"
                        )
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .disabled(isCreatingWithAI)

                Button {
                    let other: MacVocabularyItem.Language = selectedLanguage == .chinese ? .english : .chinese
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedLanguage = other
                    }
                    createWord(language: other)
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedLanguage == .chinese ? "🇺🇸" : "🇨🇳")
                        Text("Tạo thẻ \(selectedLanguage == .chinese ? "Tiếng Anh" : "Hán ngữ")")
                    }
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .disabled(isCreatingWithAI)
            }

            Spacer(minLength: 0)
        }
    }

    private var splitResultsView: some View {
        HStack(spacing: 0) {
            // Left: Results List
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(matchingItems) { item in
                                resultRow(item)
                                    .id(item.id)
                            }
                        }
                        .padding(10)
                    }
                    .accessibilityLabel("Danh sách kết quả tra cứu")
                    .onChange(of: selectedItemID) { _, newID in
                        if let newID {
                            withAnimation(.snappy(duration: 0.15)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }

                if !hasExactTermMatch {
                    Divider().opacity(0.5)
                    Button {
                        createWord(language: selectedLanguage)
                    } label: {
                        HStack(spacing: 6) {
                            if isCreatingWithAI {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(VocaDesign.brandGreen)
                            }
                            Text(
                                isCreatingWithAI
                                    ? "Đang tạo “\(trimmedQuery)”…"
                                    : "Tạo mới “\(trimmedQuery)” bằng AI"
                            )
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)

                            Spacer(minLength: 4)

                            VocaKeycap(label: "⇧↩")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingWithAI)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                }
            }
            .frame(width: 256)

            Divider().opacity(0.6)

            // Right: Rich Detail Preview
            Group {
                if let item = selectedItem {
                    detailPreviewPane(item)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func resultRow(_ item: MacVocabularyItem) -> some View {
        let isSelected = selectedItem?.id == item.id
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.language == .chinese ? "🇨🇳" : "🇺🇸")
                        .font(.system(size: 11))

                    Text(item.term)
                        .font(
                            item.language == .chinese
                                ? VocaDesign.hanziFont(size: 17, weight: .bold)
                                : .system(size: 14, weight: .bold, design: .rounded)
                        )
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(VocaDesign.accentAmber)
                    }
                }

                Text(item.displayMeaningVi)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isSelected {
                VocaKeycap(label: "↩")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    isSelected
                        ? VocaDesign.brandGreen.opacity(0.13)
                        : Color(nsColor: .controlBackgroundColor).opacity(0.65)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? VocaDesign.brandGreen.opacity(0.45)
                        : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpenWordDetail(item.id)
        }
        .onTapGesture {
            selectedItemID = item.id
        }
    }

    private func detailPreviewPane(_ item: MacVocabularyItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let creationError {
                    errorBanner(creationError)
                }

                // Metadata & Action Row
                HStack(spacing: 6) {
                    VocaPillBadge(
                        text: item.language == .chinese ? "🇨🇳 Hán ngữ" : "🇺🇸 Tiếng Anh",
                        tint: item.language == .chinese ? VocaDesign.accentAmber : VocaDesign.accentSky
                    )

                    if let pos = item.partOfSpeech, !pos.isEmpty {
                        Text(pos)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    if item.isDue {
                        VocaPillBadge(
                            text: "Đến hạn",
                            icon: "clock.fill",
                            tint: VocaDesign.accentAmber
                        )
                    }

                    Spacer()

                    previewActionButton(
                        icon: speech.isSpeaking && speech.speakingText == item.term
                            ? "stop.fill"
                            : "speaker.wave.2.fill",
                        tint: VocaDesign.brandGreen,
                        tooltip: "Phát âm (⌘P)"
                    ) {
                        speech.toggle(item.term, language: item.language)
                    }

                    previewActionButton(
                        icon: item.isFavorite ? "star.fill" : "star",
                        tint: item.isFavorite ? VocaDesign.accentAmber : .secondary,
                        tooltip: "Yêu thích (⌘D)"
                    ) {
                        toggleFavorite(item)
                    }

                    previewActionButton(
                        icon: "doc.on.doc",
                        tint: .secondary,
                        tooltip: "Sao chép thẻ từ (⌘C)"
                    ) {
                        copyItem(item)
                    }

                    Button {
                        onOpenWordDetail(item.id)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Mở kho từ")
                                .font(.system(size: 11.5, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                    .help("Mở chi tiết trong cửa sổ chính (↩)")
                }

                // Term / Hanzi Tianzige Guide
                if item.language == .chinese && VocaDesign.containsHanCharacters(item.term) {
                    MacHanziWritingGuide(
                        word: item.term,
                        compact: true,
                        tileSize: 46
                    )
                } else {
                    Text(item.term)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .textSelection(.enabled)
                }

                if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(VocaDesign.brandGreen)
                        .textSelection(.enabled)
                }

                // Meanings
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.displayMeaningVi)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    if let meaningEn = item.meaningEn,
                       !meaningEn.isEmpty,
                       meaningEn != item.displayMeaningVi {
                        Text(meaningEn)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }

                // Examples
                if !item.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VÍ DỤ NGỮ CẢNH")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        ForEach(Array(item.examples.prefix(2).enumerated()), id: \.offset) { _, example in
                            let parsed = item.language == .chinese ? ChineseExample(example) : nil
                            let spokenText = parsed?.hanzi ?? example
                            HStack(alignment: .top, spacing: 8) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(VocaDesign.brandGreen.opacity(0.65))
                                    .frame(width: 2.5)

                                if let parsed {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(parsed.hanzi)
                                            .font(VocaDesign.hanziFont(size: 14, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .textSelection(.enabled)
                                        if let pinyin = parsed.pinyin {
                                            Text(pinyin)
                                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                                .foregroundStyle(VocaDesign.brandGreen)
                                                .textSelection(.enabled)
                                        }
                                        if let meaningVi = parsed.meaningVi {
                                            Text(meaningVi)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                        }
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(example)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(.primary.opacity(0.88))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                }

                                Spacer(minLength: 4)

                                Button {
                                    speech.toggle(spokenText, language: item.language)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Nghe câu ví dụ")
                            }
                            .padding(9)
                            .background(
                                Color(nsColor: .controlBackgroundColor).opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                        }
                    }
                }

                // Memory Tip
                if let memoryTip = item.memoryTip, !memoryTip.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VocaDesign.accentAmber)
                            .padding(.top, 1)

                        Text(memoryTip)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        VocaDesign.accentAmber.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                }
            }
            .padding(16)
        }
    }

    private func previewActionButton(
        icon: String,
        tint: Color,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VocaDesign.accentRose)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(VocaDesign.accentRose)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VocaDesign.accentRose.opacity(0.10))
        )
    }

    // MARK: - Footer Shortcut Hints & Hidden Shortcuts

    private var shortcutFooterBar: some View {
        HStack(spacing: 14) {
            shortcutHint(keys: "↑↓", label: "Chọn từ")
            shortcutHint(keys: "↩", label: matchingItems.isEmpty ? "Tạo AI" : "Mở chi tiết")
            shortcutHint(keys: "⌘P", label: "Phát âm")
            shortcutHint(keys: "⌘D", label: "Yêu thích")
            shortcutHint(keys: "⌘C", label: "Sao chép")
            shortcutHint(keys: "⌘L", label: "Đổi Anh/Trung")
            Spacer(minLength: 0)
            shortcutHint(keys: "Esc", label: query.isEmpty ? "Đóng" : "Xóa tìm")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.78))
    }

    private func shortcutHint(keys: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var lookupKeyboardShortcuts: some View {
        Button("") { moveSelection(delta: -1) }
            .keyboardShortcut(.upArrow, modifiers: [])
            .hidden()

        Button("") { moveSelection(delta: 1) }
            .keyboardShortcut(.downArrow, modifiers: [])
            .hidden()

        Button("") {
            if !trimmedQuery.isEmpty {
                createWord(language: selectedLanguage)
            }
        }
        .keyboardShortcut(.return, modifiers: .shift)
        .hidden()

        Button("") { toggleLanguage() }
            .keyboardShortcut("l", modifiers: .command)
            .hidden()

        Button("") { selectedLanguage = .english }
            .keyboardShortcut("1", modifiers: .command)
            .hidden()

        Button("") { selectedLanguage = .chinese }
            .keyboardShortcut("2", modifiers: .command)
            .hidden()

        Button("") { pronounceSelectedOrQuery() }
            .keyboardShortcut("p", modifiers: .command)
            .hidden()

        Button("") {
            if let item = selectedItem {
                toggleFavorite(item)
            }
        }
        .keyboardShortcut("d", modifiers: .command)
        .hidden()

        if let item = selectedItem {
            Button("") { copyItem(item) }
                .keyboardShortcut("c", modifiers: .command)
                .hidden()
        }

        Button("") { handleEscape() }
            .keyboardShortcut(.cancelAction)
            .hidden()
    }

    // MARK: - Helpers & Actions

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedItem: MacVocabularyItem? {
        if let selectedItemID,
           let matched = matchingItems.first(where: { $0.id == selectedItemID }) {
            return matched
        }
        return matchingItems.first
    }

    private var hasExactTermMatch: Bool {
        let q = trimmedQuery
        guard !q.isEmpty else { return false }
        return matchingItems.contains { item in
            item.term.compare(q, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func syncSelectedItem() {
        if let selectedItemID,
           matchingItems.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = matchingItems.first?.id
    }

    private func moveSelection(delta: Int) {
        guard !matchingItems.isEmpty else { return }
        let currentIndex = matchingItems.firstIndex(where: { $0.id == selectedItem?.id }) ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), matchingItems.count - 1)
        selectedItemID = matchingItems[nextIndex].id
    }

    private func submitPrimaryAction() {
        if let item = selectedItem {
            onOpenWordDetail(item.id)
        } else if !trimmedQuery.isEmpty {
            createWord(language: selectedLanguage)
        }
    }

    private func handleEscape() {
        if !query.isEmpty {
            query = ""
        } else {
            onDismiss()
        }
    }

    private func toggleLanguage() {
        withAnimation(.snappy(duration: 0.18)) {
            selectedLanguage = selectedLanguage == .english ? .chinese : .english
        }
    }

    private func pronounceSelectedOrQuery() {
        if let item = selectedItem {
            speech.toggle(item.term, language: item.language)
        } else if !trimmedQuery.isEmpty {
            speech.toggle(trimmedQuery, language: selectedLanguage)
        }
    }

    private func toggleFavorite(_ item: MacVocabularyItem) {
        let willFavorite = !item.isFavorite
        vocabulary.toggleFavorite(item.id)
        showToast(
            icon: willFavorite ? "star.fill" : "star.slash",
            message: willFavorite ? "Đã lưu Yêu thích ★" : "Đã bỏ Yêu thích",
            tint: willFavorite ? VocaDesign.accentAmber : .secondary
        )
    }

    private func copyItem(_ item: MacVocabularyItem) {
        var parts = [item.term]
        if let pronunciation = item.pronunciation, !pronunciation.isEmpty {
            parts.append(pronunciation)
        }
        parts.append("— \(item.displayMeaningVi)")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: " "), forType: .string)
        showToast(
            icon: "doc.on.doc.fill",
            message: "Đã sao chép “\(item.term)”",
            tint: VocaDesign.brandGreen
        )
    }

    private func showToast(icon: String, message: String, tint: Color) {
        withAnimation(.snappy(duration: 0.18)) {
            toastState = (icon, message, tint)
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if toastState?.message == message {
                    withAnimation(.easeOut(duration: 0.2)) {
                        toastState = nil
                    }
                }
            }
        }
    }

    private var matchingItems: [MacVocabularyItem] {
        let normalizedQuery = trimmedQuery
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )

        guard !normalizedQuery.isEmpty else {
            return []
        }

        return vocabulary.items
            .filter { item in
                let searchableContent = [
                    item.term,
                    item.pronunciation ?? "",
                    item.displayMeaningVi,
                    item.meaning,
                    item.meaningEn ?? "",
                    item.language.title,
                    item.tags.joined(separator: " ")
                ]
                .joined(separator: " ")
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )

                return searchableContent.contains(normalizedQuery)
            }
            .sorted { left, right in
                let leftTerm = left.term.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
                let rightTerm = right.term.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )

                let leftExact = leftTerm == normalizedQuery
                let rightExact = rightTerm == normalizedQuery
                if leftExact != rightExact {
                    return leftExact
                }

                let leftPrefix = leftTerm.hasPrefix(normalizedQuery)
                let rightPrefix = rightTerm.hasPrefix(normalizedQuery)
                if leftPrefix != rightPrefix {
                    return leftPrefix
                }

                let leftPreferredLang = left.language == selectedLanguage
                let rightPreferredLang = right.language == selectedLanguage
                if leftPreferredLang != rightPreferredLang {
                    return leftPreferredLang
                }

                return left.term.localizedCaseInsensitiveCompare(
                    right.term
                ) == .orderedAscending
            }
    }

    private func inspectClipboardSuggestion() {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.count <= 48,
              !raw.contains("\n"),
              raw.rangeOfCharacter(from: .letters) != nil
        else {
            clipboardCandidate = nil
            return
        }
        clipboardCandidate = raw
    }

    private func createWord(language: MacVocabularyItem.Language) {
        let wordToCreate = trimmedQuery
        guard !wordToCreate.isEmpty, !isCreatingWithAI else { return }

        isCreatingWithAI = true
        creationError = nil

        Task {
            do {
                let created = try await vocabulary.create(
                    word: wordToCreate,
                    language: language
                )
                isCreatingWithAI = false
                selectedItemID = created.id
            } catch {
                isCreatingWithAI = false
                creationError = error.localizedDescription
            }
        }
    }
}

private struct MacSettingsView: View {
    @Environment(MacSessionStore.self) private var session
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(MacSpeechService.self) private var speech

    @ViewState private var serverURLInput = AppConfig.baseURL.absoluteString
    @ViewState private var isTestingServer = false
    @ViewState private var serverCheckMessage: String?
    @ViewState private var isServerHealthy: Bool?

    private var appearance: Binding<MacPreferencesStore.Appearance> {
        Binding(
            get: { preferences.appearance },
            set: preferences.setAppearance
        )
    }

    private var defaultDestination:
        Binding<MacPreferencesStore.DefaultDestination> {
        Binding(
            get: { preferences.defaultDestination },
            set: preferences.setDefaultDestination
        )
    }

    private var showInMenuBar: Binding<Bool> {
        Binding(
            get: { preferences.showInMenuBar },
            set: preferences.setShowInMenuBar
        )
    }

    private var menuBarBadgeStyle: Binding<MacPreferencesStore.MenuBarBadgeStyle> {
        Binding(
            get: { preferences.menuBarBadgeStyle },
            set: preferences.setMenuBarBadgeStyle
        )
    }

    private var quickLookupHotkey: Binding<MacPreferencesStore.QuickLookupHotkey> {
        Binding(
            get: { preferences.quickLookupHotkey },
            set: preferences.setQuickLookupHotkey
        )
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { preferences.launchAtLogin },
            set: preferences.setLaunchAtLogin
        )
    }

    private var hideDockIcon: Binding<Bool> {
        Binding(
            get: { preferences.hideDockIcon },
            set: preferences.setHideDockIcon
        )
    }

    private var dailyGoal: Binding<Int> {
        Binding(
            get: { preferences.dailyGoal },
            set: preferences.setDailyGoal
        )
    }

    private var playAudioAutomatically: Binding<Bool> {
        Binding(
            get: { preferences.playAudioAutomatically },
            set: preferences.setPlayAudioAutomatically
        )
    }

    private var enableAssistantFeatures: Binding<Bool> {
        Binding(
            get: { preferences.enableAssistantFeatures },
            set: preferences.setEnableAssistantFeatures
        )
    }

    var body: some View {
        TabView {
            generalSettingsTab
                .tabItem {
                    Label("Chung", systemImage: "gearshape")
                }

            menuBarAndShortcutsTab
                .tabItem {
                    Label("Menu Bar & Phím tắt", systemImage: "menubar.rectangle")
                }

            audioAndAITab
                .tabItem {
                    Label("Âm thanh & AI", systemImage: "waveform")
                }

            serverSettingsTab
                .tabItem {
                    Label("Máy chủ", systemImage: "server.rack")
                }
        }
        .frame(width: 580, height: 470)
    }

    private var generalSettingsTab: some View {
        Form {
            Section("Giao diện & Điều hướng") {
                Picker("Chế độ giao diện", selection: appearance) {
                    ForEach(MacPreferencesStore.Appearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker("Màn hình mở mặc định", selection: defaultDestination) {
                    ForEach(MacPreferencesStore.DefaultDestination.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Stepper(
                    "Mục tiêu hàng ngày: \(preferences.dailyGoal) hoạt động",
                    value: dailyGoal,
                    in: 1...100
                )
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Khôi phục cài đặt mặc định")
                            .font(.body)
                        Text("Đặt lại giao diện, Menu Bar, phím tắt và mục tiêu học tập về ban đầu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Đặt lại mặc định", role: .destructive) {
                        preferences.reset()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var menuBarAndShortcutsTab: some View {
        Form {
            Section("Thanh Menu Bar macOS") {
                Toggle("Hiển thị Voca trên thanh Menu Bar", isOn: showInMenuBar)

                Picker("Kiểu huy hiệu trên Menu Bar", selection: menuBarBadgeStyle) {
                    ForEach(MacPreferencesStore.MenuBarBadgeStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!preferences.showInMenuBar)

                Toggle("Ẩn biểu tượng dưới Dock (chế độ Menu Bar gọn nhẹ)", isOn: hideDockIcon)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Khởi động cùng macOS", isOn: launchAtLogin)

                    if preferences.launchAtLogin, let error = preferences.launchAtLoginError {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(VocaDesign.accentAmber)
                                Text("Chưa kích hoạt tự động mở: \(error)")
                                    .font(.caption)
                                    .foregroundStyle(VocaDesign.accentAmber)
                            }
                            Button("Mở Cài đặt Hệ thống > Mục đăng nhập") {
                                MacSystemIntegrations.openLoginItemsSettings()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VocaDesign.accentAmber.opacity(0.12))
                        )
                    }
                }
            }

            Section("Phím tắt toàn hệ thống & Nhắc nhở") {
                Picker("Phím tắt Tra từ nổi (Quick Lookup)", selection: quickLookupHotkey) {
                    ForEach(MacPreferencesStore.QuickLookupHotkey.allCases) { hotkey in
                        Text(hotkey.title).tag(hotkey)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nhắc nhở ôn tập FSRS hàng ngày")
                        Text("Thông báo nhẹ nhàng vào 20:00 khi còn thẻ từ đến hạn.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Kích hoạt thông báo") {
                        MacSystemIntegrations.requestNotificationPermissionAndSchedule(
                            dueCount: max(preferences.dailyGoal, 5)
                        )
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var audioAndAITab: some View {
        Form {
            Section("Giọng đọc bản xứ (macOS Speech)") {
                Toggle("Tự động phát âm khi lật thẻ hoặc mở từ", isOn: playAudioAutomatically)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Giọng Tiếng Anh (en-US)")
                        Text(speech.preferredVoiceSummary(for: .english))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Nghe thử") {
                        speech.speak("Serendipity brings pleasant discoveries.", language: .english)
                    }
                    .controlSize(.small)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Giọng Hán ngữ (zh-CN)")
                        Text(speech.preferredVoiceSummary(for: .chinese))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Nghe thử") {
                        speech.speak("温故而知新", language: .chinese)
                    }
                    .controlSize(.small)
                }

                Text("Mẹo: Tải giọng đọc Enhanced / Premium trong Cài đặt Hệ thống > Trợ năng > Nội dung được đọc để Voca tự động ưu tiên chất lượng cao nhất.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Gia sư AI & Tạo từ thông minh") {
                Toggle("Bật tính năng trợ lý Gia sư AI", isOn: enableAssistantFeatures)
            }
        }
        .formStyle(.grouped)
    }

    private var serverSettingsTab: some View {
        Form {
            Section("Máy chủ Voca Backend") {
                VocaInputField(
                    icon: "server.rack",
                    placeholder: "Địa chỉ máy chủ (URL)",
                    text: $serverURLInput,
                    onSubmit: {
                        testAndSaveServerURL()
                    }
                )

                HStack(spacing: 10) {
                    Button {
                        testAndSaveServerURL()
                    } label: {
                        HStack(spacing: 6) {
                            if isTestingServer {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isTestingServer ? "Đang kiểm tra…" : "Lưu & Kiểm tra kết nối")
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .disabled(isTestingServer)

                    Button("Dùng Localhost (22052)") {
                        serverURLInput = AppConfig.simulatorURL.absoluteString
                        testAndSaveServerURL()
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())

                    Button("Dùng Production") {
                        let previousURL = AppConfig.baseURL.absoluteString
                        AppConfig.resetToDefault()
                        serverURLInput = AppConfig.baseURL.absoluteString
                        serverCheckMessage = "Đã đặt về máy chủ chính thức (\(serverURLInput))."
                        isServerHealthy = true
                        if previousURL != serverURLInput, session.isSignedIn {
                            session.signOut()
                        }
                    }
                    .buttonStyle(VocaSecondaryButtonStyle())
                }

                if let serverCheckMessage {
                    Label(
                        serverCheckMessage,
                        systemImage: isServerHealthy == true
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(isServerHealthy == true ? Color.green : Color.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func testAndSaveServerURL() {
        isTestingServer = true
        serverCheckMessage = nil

        Task {
            let previousURL = AppConfig.baseURL.absoluteString
            let result = await ApiClient.shared.checkHealth(for: serverURLInput)
            if result.ok, let validURL = try? AppConfig.setCustomURL(serverURLInput) {
                serverURLInput = validURL.absoluteString
                if previousURL != serverURLInput, session.isSignedIn {
                    session.signOut()
                }
            }
            isTestingServer = false
            isServerHealthy = result.ok
            serverCheckMessage = result.message
        }
    }
}
