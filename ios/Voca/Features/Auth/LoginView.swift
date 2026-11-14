import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showRegister = false
    @State private var showServerSheet = false
    @State private var serverOnline: Bool?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !isBusy && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private var currentServerDisplay: String {
        AppConfig.baseURL.host ?? AppConfig.baseURL.absoluteString
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        heroHeader
                            .padding(.top, 24)

                        loginCard

                        registerPrompt
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerSheet = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("Cài đặt máy chủ")
                }
            }
            .safeAreaInset(edge: .bottom) { connectionBadge }
            .sheet(isPresented: $showServerSheet) {
                ServerConfigSheet {
                    refreshHealth()
                }
            }
            .task { refreshHealth() }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: 14) {
            VocaBrandMark(size: 72)

            VStack(spacing: 5) {
                Text("Voca")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Từ điển AI & Luyện tập Song ngữ Anh – Trung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Card

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Đăng nhập")
                    .font(.title3.weight(.bold))
                Text("Tiếp tục kho từ vựng và tiến độ ôn tập FSRS của bạn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                inputRow(
                    icon: "envelope.fill",
                    isFocused: focusedField == .email
                ) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                }

                inputRow(
                    icon: "lock.fill",
                    isFocused: focusedField == .password
                ) {
                    Group {
                        if showPassword {
                            TextField("Mật khẩu", text: $password)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Mật khẩu", text: $password)
                                .textContentType(.password)
                        }
                    }
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit { if canSubmit { submit() } }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                }
            }

            if let errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button(action: submit) {
                HStack(spacing: 8) {
                    if isBusy { ProgressView().tint(.white) }
                    Text("Đăng nhập")
                }
            }
            .buttonStyle(BrandCTAButtonStyle())
            .disabled(!canSubmit)
            .padding(.top, 4)

            Button {
                showServerSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.caption)
                        .foregroundStyle(Brand.green)
                    Text("Máy chủ: \(currentServerDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("Đổi")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Brand.elevatedFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .brandCard(padding: 20, cornerRadius: 22)
    }

    private var registerPrompt: some View {
        Button {
            showRegister = true
        } label: {
            HStack(spacing: 4) {
                Text("Chưa có tài khoản?")
                    .foregroundStyle(.secondary)
                Text("Đăng ký ngay")
                    .fontWeight(.semibold)
                    .foregroundStyle(Brand.green)
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }

    private func inputRow<Content: View>(
        icon: String,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isFocused ? Brand.green : .secondary)
                .frame(width: 20)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Brand.elevatedFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    isFocused ? Brand.green : Brand.hairlineBorder(for: colorScheme),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }

    @ViewBuilder private var connectionBadge: some View {
        Button {
            showServerSheet = true
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(serverOnline == nil ? .gray : (serverOnline == true ? Brand.semanticSuccess : .red))
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private var statusText: String {
        switch serverOnline {
        case .some(true): return "Máy chủ trực tuyến · \(AppConfig.baseURL.host ?? AppConfig.baseURL.absoluteString)"
        case .some(false): return "Không kết nối được máy chủ"
        case .none: return "Đang kiểm tra kết nối…"
        }
    }

    private func refreshHealth() {
        Task {
            serverOnline = nil
            let online = await ApiClient.shared.health()
            await MainActor.run {
                serverOnline = online
            }
        }
    }

    private func submit() {
        focusedField = nil
        Haptics.impact(.light)
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await auth.login(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password)
                Haptics.notify(.success)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
            }
            isBusy = false
        }
    }
}

// MARK: - Server Configuration Sheet

struct ServerConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void = {}

    @State private var serverUrl: String = ""
    @State private var isTesting = false
    @State private var testResult: (ok: Bool, message: String)?
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private struct PresetItem: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let url: String
    }

    private var presets: [PresetItem] {
        [
            PresetItem(
                name: "Chính thức (Production)",
                description: "Máy chủ trực tuyến đám mây",
                url: AppConfig.productionURL.absoluteString
            ),
            PresetItem(
                name: "Máy ảo (Simulator)",
                description: "Backend chạy trên cổng 22052",
                url: AppConfig.simulatorURL.absoluteString
            )
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("http:// hoặc https://...", text: $serverUrl)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isFocused)

                        if !serverUrl.isEmpty {
                            Button {
                                serverUrl = ""
                                testResult = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isTesting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Đang kiểm tra kết nối…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if let testResult {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: testResult.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(testResult.ok ? .green : .red)
                            Text(testResult.message)
                                .font(.footnote)
                                .foregroundStyle(testResult.ok ? .green : .red)
                        }
                    }

                    Button {
                        testCurrent()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Kiểm tra kết nối")
                        }
                    }
                    .disabled(isTesting || serverUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Địa chỉ máy chủ")
                } footer: {
                    Text("Hỗ trợ http:// và https://. Tự động kiểm tra probe GET /v1/health.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Gợi ý máy chủ") {
                    ForEach(presets) { preset in
                        Button {
                            serverUrl = preset.url
                            testCurrent()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(preset.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isSelected(preset.url) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        resetToDefault()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Khôi phục mặc định")
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mặc định: \(AppConfig.defaultBaseURL.absoluteString)")
                        Text("Nếu chạy backend trên máy tính khác trong cùng Wi-Fi, hãy nhập: http://<IP-máy-tính>:22052")
                    }
                    .font(.caption2)
                }
            }
            .navigationTitle("Cài đặt máy chủ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        save()
                    }
                    .bold()
                    .disabled(serverUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                serverUrl = AppConfig.baseURL.absoluteString
            }
        }
    }

    private func isSelected(_ candidate: String) -> Bool {
        let norm1 = (try? AppConfig.normalizeAndValidate(url: candidate))?.absoluteString
        let norm2 = (try? AppConfig.normalizeAndValidate(url: serverUrl))?.absoluteString
        return norm1 != nil && norm1 == norm2
    }

    private func testCurrent() {
        isFocused = false
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
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resetToDefault() {
        AppConfig.resetToDefault()
        serverUrl = AppConfig.defaultBaseURL.absoluteString
        testResult = nil
        errorMessage = nil
        testCurrent()
    }
}
