import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

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
        ZStack {
            VocaThemeBackground()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        VocaIconBadge(systemImage: "person.badge.plus", size: 54, iconSize: 24)
                        Text("Tạo tài khoản mới")
                            .font(.title2.weight(.bold))
                        Text("Đồng bộ từ vựng Anh – Trung và tiến độ FSRS mọi lúc.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        fieldRow(icon: "envelope.fill") {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        fieldRow(icon: "person.fill") {
                            TextField("Tên hiển thị (tùy chọn)", text: $displayName)
                        }

                        Divider().opacity(0.6)

                        fieldRow(icon: "lock.fill") {
                            SecureField("Mật khẩu (tối thiểu 6 ký tự)", text: $password)
                        }

                        fieldRow(icon: "lock.rotation") {
                            SecureField("Nhập lại mật khẩu", text: $confirm)
                        }

                        if !password.isEmpty {
                            HStack(spacing: 12) {
                                Label(
                                    "Tối thiểu 6 ký tự",
                                    systemImage: password.count >= 6 ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundStyle(password.count >= 6 ? Brand.semanticSuccess : .secondary)

                                if !confirm.isEmpty {
                                    Label(
                                        passwordsMatch ? "Khớp mật khẩu" : "Chưa khớp",
                                        systemImage: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill"
                                    )
                                    .foregroundStyle(passwordsMatch ? Brand.semanticSuccess : .red)
                                }
                            }
                            .font(.caption)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button(action: submit) {
                            HStack(spacing: 8) {
                                if isBusy { ProgressView().tint(.white) }
                                Text("Tạo tài khoản")
                            }
                        }
                        .buttonStyle(BrandCTAButtonStyle())
                        .disabled(!canSubmit)
                        .padding(.top, 4)
                    }
                    .brandCard(padding: 20, cornerRadius: 22)
                }
                .padding(20)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Đăng ký")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                .strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1)
        )
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
                Haptics.notify(.success)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
            }
            isBusy = false
        }
    }
}
