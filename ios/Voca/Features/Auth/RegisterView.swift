import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var passwordsMatch: Bool { !password.isEmpty && password == confirm }
    private var canSubmit: Bool {
        !isBusy
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && passwordsMatch
    }

    var body: some View {
        Form {
            Section("Tài khoản") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Tên hiển thị (tùy chọn)", text: $displayName)
            }

            Section("Mật khẩu") {
                SecureField("Mật khẩu (tối thiểu 6 ký tự)", text: $password)
                SecureField("Nhập lại mật khẩu", text: $confirm)
                if !confirm.isEmpty && !passwordsMatch {
                    Text("Mật khẩu nhập lại không khớp.").font(.footnote).foregroundStyle(.red)
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        if isBusy { ProgressView().padding(.trailing, 4) }
                        Text("Tạo tài khoản")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Đăng ký")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await auth.register(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    displayName: displayName)
                // On success `auth.phase` flips to .signedIn and RootView swaps the whole tree.
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isBusy = false
        }
    }
}
