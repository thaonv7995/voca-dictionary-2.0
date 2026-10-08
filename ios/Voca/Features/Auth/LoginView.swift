import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showRegister = false
    @State private var showServerSheet = false
    @State private var serverOnline: Bool?

    private var canSubmit: Bool {
        !isBusy && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private var currentServerDisplay: String {
        AppConfig.baseURL.host ?? AppConfig.baseURL.absoluteString
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Mật khẩu", text: $password)
                        .textContentType(.password)
                        .onSubmit { if canSubmit { submit() } }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            if isBusy { ProgressView().padding(.trailing, 4) }
                            Text("Đăng nhập")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }

                Section {
                    Button("Chưa có tài khoản? Đăng ký") { showRegister = true }
                }

                Section("Máy chủ kết nối") {
                    Button {
                        showServerSheet = true
                    } label: {
                        HStack {
                            Label("Máy chủ", systemImage: "server.rack")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(currentServerDisplay)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Voca")
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerSheet = true
                    } label: {
                        Image(systemName: "network")
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

    @ViewBuilder private var connectionBadge: some View {
        Button {
            showServerSheet = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(serverOnline == nil ? .gray : (serverOnline == true ? .green : .red))
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private var statusText: String {
        switch serverOnline {
        case .some(true): return "Máy chủ trực tuyến · \(AppConfig.baseURL.absoluteString)"
        case .some(false): return "Không kết nối được \(AppConfig.baseURL.absoluteString)"
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
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await auth.login(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isBusy = false
        }
    }
}

// MARK: - Server Configuration Sheet

struct ServerConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

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

