import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth

    @State private var displayName = ""
    @State private var isSavingName = false
    @State private var statusMessage: String?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tài khoản") {
                    LabeledContent("Email", value: auth.user?.email ?? "—")
                    if auth.user?.admin == true {
                        LabeledContent("Vai trò", value: "ADMIN")
                    }
                }

                Section("Tên hiển thị") {
                    TextField("Tên hiển thị", text: $displayName)
                    Button {
                        saveName()
                    } label: {
                        HStack {
                            if isSavingName { ProgressView().padding(.trailing, 4) }
                            Text("Lưu tên")
                        }
                    }
                    .disabled(isSavingName || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    NavigationLink("Đổi mật khẩu") { ChangePasswordView() }
                    Button {
                        showSettings = true
                    } label: {
                        Label("Cài đặt (AI, TTS, API keys)", systemImage: "gearshape")
                    }
                }

                if let statusMessage {
                    Section { Text(statusMessage).foregroundStyle(.secondary) }
                }

                Section {
                    Button("Đăng xuất", role: .destructive) {
                        Task { await auth.logout() }
                    }
                }
            }
            .navigationTitle("Hồ sơ")
            .onAppear { displayName = auth.user?.displayName ?? "" }
            .sheet(isPresented: $showSettings) { SettingsRootView() }
        }
    }

    private func saveName() {
        isSavingName = true
        statusMessage = nil
        Task {
            do {
                try await auth.updateProfile(displayName: displayName)
                statusMessage = "Đã cập nhật tên hiển thị."
            } catch {
                statusMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isSavingName = false
        }
    }
}
