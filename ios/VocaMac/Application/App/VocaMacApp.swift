import AppKit
import CoreSpotlight
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>
extension StudyService: @unchecked Sendable {}
extension CardsService: @unchecked Sendable {}

@main
struct VocaMacApp: App {
    @ViewState private var router = MacAppRouter()
    @ViewState private var session = MacSessionStore()
    @ViewState private var preferences = MacPreferencesStore()
    @ViewState private var ledger: MacActivityLedger
    @ViewState private var vocabulary: MacVocabularyStore
    @ViewState private var review: MacReviewStore
    @ViewState private var today: MacTodayStore
    @ViewState private var speech = MacSpeechService()

    init() {
        VocaDesign.ensureChineseFontsRegistered()
        let activityLedger = MacActivityLedger()
        _ledger = State(initialValue: activityLedger)
        _vocabulary = State(
            initialValue: MacVocabularyStore(ledger: activityLedger)
        )
        _review = State(
            initialValue: MacReviewStore(ledger: activityLedger)
        )
        _today = State(
            initialValue: MacTodayStore(ledger: activityLedger)
        )
    }

    private var menuBarSelection: Binding<Bool> {
        Binding(
            get: { preferences.showInMenuBar },
            set: { preferences.setShowInMenuBar($0) }
        )
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
            CommandMenu("Navigate") {
                ForEach(Array(MacDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                    Button(destination.title) {
                        router.select(destination)
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                }
            }

            CommandGroup(after: .newItem) {
                Button("Add Word…") {
                    router.requestAddWord()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Quick Lookup") {
                    MacQuickLookupPanelController.shared.toggleFloatingPanel()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Floating Quick Lookup Panel") {
                    MacQuickLookupPanelController.shared.toggleFloatingPanel()
                }
                .keyboardShortcut(.space, modifiers: .option)

                Divider()

                Button("Import Vocabulary…") {
                    router.requestImportExport(mode: .importWords)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Vocabulary…") {
                    router.requestImportExport(mode: .exportWords)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Window("Review Session", id: "review-focus") {
            MacReviewView(isFocusWindow: true)
                .environment(router)
                .environment(session)
                .environment(preferences)
                .environment(ledger)
                .environment(vocabulary)
                .environment(review)
                .environment(today)
                .environment(speech)
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
        } label: {
            Image(nsImage: VocaDesign.menuBarStatusImage)
                .accessibilityLabel("Voca")
        }
        .menuBarExtraStyle(.window)

        Settings {
            MacSettingsView()
                .environment(preferences)
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
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Loading Voca…")
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
                vocabulary: vocabulary,
                speech: speech
            )
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

                        HStack(spacing: 16) {
                            Button("Chưa có tài khoản? Đăng ký") {
                                showRegisterSheet = true
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VocaDesign.brandGreen)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Button("Dùng thử Preview") {
                                session.usePreviewAccount()
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .disabled(session.isSigningIn)
                        }
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
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
                .keyboardShortcut("/", modifiers: .command)
                .help("Phím tắt toàn hệ thống (⌘/)")

                Button {
                    router.open(.quickLookup(query: nil))
                } label: {
                    Label("Quick Lookup", systemImage: "magnifyingglass")
                }
                .help("Tra nhanh từ vựng (⌥Space / ⇧⌘K)")

                Button {
                    router.requestImportExport(mode: .importWords)
                } label: {
                    Label("Import / Export", systemImage: "square.and.arrow.down")
                }
                .help("Nhập / Xuất từ vựng (⇧⌘I)")

                Button {
                    router.requestAddWord()
                } label: {
                    Label("Add Word", systemImage: "plus")
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
            "Unable to Open Link",
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
            Button("OK") {
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
                            ? "Syncing…"
                            : (vocabulary.pendingMutationCount > 0
                                ? "\(vocabulary.pendingMutationCount) pending"
                                : "Cloud Synced")
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                router.open(.quickLookup(query: nil))
            } label: {
                Text("⌥Space")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Open Quick Lookup (Option + Space)")
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
                Button("Import Vocabulary…") {
                    router.requestImportExport(mode: .importWords)
                }

                Button("Export Vocabulary…") {
                    router.requestImportExport(mode: .exportWords)
                }

                Divider()

                Button("Settings…") {
                    openSettings()
                }

                Divider()

                Button("Sign Out", role: .destructive) {
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
            .accessibilityLabel("Account menu")
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
            // Spotlight / Raycast Top Search Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VocaDesign.brandGreen)

                TextField("Tra từ vựng, ngữ nghĩa, Pinyin/IPA hoặc thêm từ bằng AI…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = matchingItems.first {
                            onOpenWordDetail(first.id)
                        } else if !trimmedQuery.isEmpty {
                            createWord(language: selectedLanguage)
                        }
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
                }

                Spacer(minLength: 4)

                // Trailing Flag Switcher + ESC button (Sát mép phải)
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                selectedLanguage = .english
                            }
                        } label: {
                            Text("🇺🇸")
                                .font(.system(size: 16))
                                .frame(width: 30, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedLanguage == .english ? Color.primary.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            selectedLanguage == .english ? VocaDesign.accentSky.opacity(0.5) : Color.clear,
                                            lineWidth: 1.2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Tiếng Anh (⌘L / ⌘1)")

                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                selectedLanguage = .chinese
                            }
                        } label: {
                            Text("🇨🇳")
                                .font(.system(size: 16))
                                .frame(width: 30, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedLanguage == .chinese ? Color.primary.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            selectedLanguage == .chinese ? VocaDesign.accentAmber.opacity(0.5) : Color.clear,
                                            lineWidth: 1.2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Hán ngữ (⌘L / ⌘2)")
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
                    .keyboardShortcut(.cancelAction)
                    .help("Đóng (ESC)")
                }

                // Hot-Switch Shortcuts
                Button("") {
                    toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: .command)
                .hidden()

                Button("") {
                    selectedLanguage = .english
                }
                .keyboardShortcut("1", modifiers: .command)
                .hidden()

                Button("") {
                    selectedLanguage = .chinese
                }
                .keyboardShortcut("2", modifiers: .command)
                .hidden()
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))

            Divider().opacity(0.6)

            // Body Area
            VStack(alignment: .leading, spacing: 14) {
                if trimmedQuery.isEmpty, let clipboardCandidate {
                    HStack(spacing: 12) {
                        VocaIconBadge(
                            systemImage: "doc.on.clipboard.fill",
                            tint: VocaDesign.brandGreen,
                            size: 32,
                            iconSize: 14
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gợi ý từ bộ nhớ tạm")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("Tra từ “\(clipboardCandidate)”")
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

                if let creationError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VocaDesign.accentRose)
                        Text(creationError)
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

                if trimmedQuery.isEmpty {
                    VStack(spacing: 12) {
                        VocaIconBadge(
                            systemImage: "sparkles",
                            tint: VocaDesign.brandGreen,
                            size: 48,
                            iconSize: 22
                        )
                        Text("Tra cứu nhanh & Tạo từ với AI")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Nhập từ tiếng Anh hoặc chữ Hán để xem phiên âm, giải nghĩa và phát âm tức thì.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if matchingItems.isEmpty {
                    VStack(spacing: 14) {
                        VocaIconBadge(
                            systemImage: "sparkles",
                            tint: VocaDesign.brandGreen,
                            size: 48,
                            iconSize: 22
                        )

                        Text("“\(trimmedQuery)” chưa có trong từ điển")
                            .font(.system(size: 16, weight: .bold, design: .rounded))

                        Text("Tự động tạo thẻ từ hoàn chỉnh với phiên âm, giải nghĩa tiếng Việt và câu ví dụ bằng AI.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)

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
                                            : "Tạo thẻ \(selectedLanguage == .chinese ? "Hán ngữ" : "Tiếng Anh") bằng AI (↩)"
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
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(matchingItems) { item in
                                let isSelected = selectedItemID == item.id
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(item.term)
                                                .font(
                                                    item.language == .chinese
                                                        ? VocaDesign.hanziFont(size: 20, weight: .bold)
                                                        : .system(size: 15.5, weight: .bold, design: .rounded)
                                                )

                                            if let pronunciation = item.pronunciation {
                                                Text(pronunciation)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundStyle(VocaDesign.brandGreen)
                                            }

                                            if let pos = item.partOfSpeech, !pos.isEmpty {
                                                Text(pos)
                                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.primary.opacity(0.06), in: Capsule())
                                            }

                                            if item.isFavorite {
                                                Image(systemName: "star.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(VocaDesign.accentAmber)
                                            }
                                        }

                                        Text(item.displayMeaningVi)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Button {
                                        speech.toggle(item.term, language: item.language)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(VocaDesign.brandGreen)
                                            .frame(width: 28, height: 28)
                                            .background(VocaDesign.brandGreen.opacity(0.12), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Nghe phát âm")

                                    Button("Mở") {
                                        onOpenWordDetail(item.id)
                                    }
                                    .buttonStyle(VocaSecondaryButtonStyle())
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(
                                            isSelected
                                                ? VocaDesign.brandGreen.opacity(0.10)
                                                : Color(nsColor: .controlBackgroundColor)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(
                                            isSelected
                                                ? VocaDesign.brandGreen.opacity(0.45)
                                                : Color.primary.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                                .onTapGesture {
                                    selectedItemID = item.id
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Lookup results")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VocaDesign.subtleWindowBackground)
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            selectedItemID = matchingItems.first?.id
            inspectClipboardSuggestion()
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .task {
            await vocabulary.load()
            selectedItemID = matchingItems.first?.id
            try? await Task.sleep(nanoseconds: 50_000_000)
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notif in
            if let window = notif.object as? NSWindow, window === NSApp.keyWindow {
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
            selectedItemID = matchingItems.first?.id
        }
        .onChange(of: vocabulary.items) { _, _ in
            selectedItemID = matchingItems.first?.id
        }
        .onChange(of: selectedLanguage) { _, _ in
            selectedItemID = matchingItems.first?.id
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleLanguage() {
        withAnimation(.snappy(duration: 0.18)) {
            selectedLanguage = selectedLanguage == .english ? .chinese : .english
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

        let baseItems = vocabulary.items.filter { $0.language == selectedLanguage }

        return baseItems
            .filter { item in
                let searchableContent = [
                    item.term,
                    item.pronunciation ?? "",
                    item.meaning,
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
                let leftIsExact = left.term.compare(
                    normalizedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
                let rightIsExact = right.term.compare(
                    normalizedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame

                if leftIsExact != rightIsExact {
                    return leftIsExact
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

    private func detectedLanguage(
        for text: String
    ) -> MacVocabularyItem.Language {
        VocaDesign.containsHanCharacters(text) ? .chinese : .english
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
    @Environment(MacPreferencesStore.self) private var preferences

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
        Form {
            Section("Cài đặt chung") {
                Picker("Giao diện", selection: appearance) {
                    ForEach(
                        MacPreferencesStore.Appearance.allCases
                    ) { option in
                        Text(option.title)
                            .tag(option)
                    }
                }

                Picker(
                    "Mở Voca tại",
                    selection: defaultDestination
                ) {
                    ForEach(
                        MacPreferencesStore.DefaultDestination.allCases
                    ) { option in
                        Text(option.title)
                            .tag(option)
                    }
                }

                Stepper(
                    "Mục tiêu hàng ngày: \(preferences.dailyGoal) hoạt động",
                    value: dailyGoal,
                    in: 1...100
                )
            }

            Section("Âm thanh & AI Assistant") {
                Toggle(
                    "Tự động phát âm từ vựng",
                    isOn: playAudioAutomatically
                )

                Toggle(
                    "Bật tính năng trợ lý AI Assistant",
                    isOn: enableAssistantFeatures
                )
            }

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
                        AppConfig.resetToDefault()
                        serverURLInput = AppConfig.baseURL.absoluteString
                        serverCheckMessage = "Đã đặt về máy chủ chính thức (\(serverURLInput))."
                        isServerHealthy = true
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

            Section("Tích hợp hệ thống macOS") {
                Toggle(
                    "Hiển thị Voca trên thanh Menu Bar",
                    isOn: showInMenuBar
                )

                Toggle(
                    "Ẩn icon dưới Dock (chế độ Menu Bar)",
                    isOn: hideDockIcon
                )

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(
                        "Khởi động cùng macOS",
                        isOn: launchAtLogin
                    )

                    if preferences.launchAtLogin, let error = preferences.launchAtLoginError {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(VocaDesign.accentAmber)
                                Text("Chưa được kích hoạt tự động mở: \(error)")
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

                Button("Bật thông báo nhắc nhở ôn tập hàng ngày") {
                    MacSystemIntegrations.requestNotificationPermissionAndSchedule(
                        dueCount: max(preferences.dailyGoal, 5)
                    )
                }
                .controlSize(.small)

                Text(
                    "Khi bật Menu Bar, bạn có thể tra nhanh từ điển (⌥Space), ôn tập siêu tốc "
                    + "và xem từ vựng trong ngày mà không cần mở toàn bộ cửa sổ ứng dụng."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Khôi phục cài đặt mặc định", role: .destructive) {
                    preferences.reset()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 620)
        .padding()
    }

    private func testAndSaveServerURL() {
        isTestingServer = true
        serverCheckMessage = nil

        Task {
            let result = await ApiClient.shared.checkHealth(for: serverURLInput)
            if let validURL = try? AppConfig.setCustomURL(serverURLInput) {
                serverURLInput = validURL.absoluteString
            }
            isTestingServer = false
            isServerHealthy = result.ok
            serverCheckMessage = result.message
        }
    }
}
