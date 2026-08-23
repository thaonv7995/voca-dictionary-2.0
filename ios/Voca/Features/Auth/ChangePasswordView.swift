import SwiftUI

struct ChangePasswordView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private var canSubmit: Bool {
        !isBusy && !current.isEmpty && newPassword.count >= 6 && newPassword == confirm
    }

    var body: some View {
        Form {
            Section("Mật khẩu hiện tại") {
                SecureField("Mật khẩu hiện tại", text: $current)
            }

            Section("Mật khẩu mới") {
                SecureField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $newPassword)
                SecureField("Nhập lại mật khẩu mới", text: $confirm)
                if !confirm.isEmpty && newPassword != confirm {
                    Text("Mật khẩu nhập lại không khớp.").font(.footnote).foregroundStyle(.red)
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
            if didSucceed {
                Section { Text("Đã đổi mật khẩu.").foregroundStyle(.green) }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        if isBusy { ProgressView().padding(.trailing, 4) }
                        Text("Đổi mật khẩu")
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Đổi mật khẩu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await auth.changePassword(current: current, new: newPassword)
                didSucceed = true
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isBusy = false
        }
    }
}
