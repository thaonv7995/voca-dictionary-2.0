import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showRegister = false
    @State private var serverOnline: Bool?

    private var canSubmit: Bool {
        !isBusy && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
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
            }
            .navigationTitle("Voca")
            .navigationDestination(isPresented: $showRegister) { RegisterView() }
            .safeAreaInset(edge: .bottom) { connectionBadge }
            .task { serverOnline = await ApiClient.shared.health() }
        }
    }

    @ViewBuilder private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(serverOnline == nil ? .gray : (serverOnline == true ? .green : .red))
                .frame(width: 8, height: 8)
            Text(statusText).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var statusText: String {
        switch serverOnline {
        case .some(true): return "Máy chủ trực tuyến · \(AppConfig.baseURL.absoluteString)"
        case .some(false): return "Không kết nối được \(AppConfig.baseURL.absoluteString)"
        case .none: return "Đang kiểm tra kết nối…"
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
