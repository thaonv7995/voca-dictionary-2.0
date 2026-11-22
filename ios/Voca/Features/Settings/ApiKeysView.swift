import SwiftUI
import UIKit

/// Self-service API-key management: list, revoke, delete, and create (plaintext shown once).
struct ApiKeysView: View {
    private let service = SettingsService()

    @State private var keys: [ApiKeyInfo] = []
    @State private var scopes: [OfferedScope] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var pendingDeleteKey: ApiKeyInfo?
    @State private var pendingRevokeKey: ApiKeyInfo?

    var body: some View {
        List {
            if isLoading && keys.isEmpty {
                Section {
                    HStack {
                        ProgressView().padding(.trailing, 4)
                        Text("Đang tải…").foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            if keys.isEmpty && !isLoading {
                Section {
                    Text("Chưa có API key nào. Nhấn + để tạo key mới.")
                        .foregroundStyle(.secondary)
                }
            } else if !keys.isEmpty {
                Section("API keys của bạn") {
                    ForEach(keys) { key in
                        keyRow(key)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Xóa", role: .destructive) { pendingDeleteKey = key }
                                if !isRevoked(key) {
                                    Button("Thu hồi") { pendingRevokeKey = key }.tint(.orange)
                                }
                            }
                    }
                }
            }

            if !scopes.isEmpty {
                Section {
                    ForEach(scopes) { scope in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scope.label).font(.subheadline)
                            Text(scope.endpoints)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Phạm vi truy cập (scopes)")
                } footer: {
                    Text("Mỗi key có thể được cấp một hoặc nhiều phạm vi ở trên.")
                }
            }
        }
        .navigationTitle("API keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Tạo API key")
            }
        }
        .task { await load() }
        .alert(
            "Xóa API key “\(pendingDeleteKey?.name ?? "")”?",
            isPresented: Binding(
                get: { pendingDeleteKey != nil },
                set: { if !$0 { pendingDeleteKey = nil } }
            )
        ) {
            Button("Xóa vĩnh viễn", role: .destructive) {
                if let target = pendingDeleteKey { delete(target) }
                pendingDeleteKey = nil
            }
            Button("Hủy", role: .cancel) { pendingDeleteKey = nil }
        } message: {
            Text("Các công cụ đang sử dụng API key này sẽ ngừng hoạt động ngay lập tức.")
        }
        .alert(
            "Thu hồi API key “\(pendingRevokeKey?.name ?? "")”?",
            isPresented: Binding(
                get: { pendingRevokeKey != nil },
                set: { if !$0 { pendingRevokeKey = nil } }
            )
        ) {
            Button("Thu hồi", role: .destructive) {
                if let target = pendingRevokeKey { revoke(target) }
                pendingRevokeKey = nil
            }
            Button("Hủy", role: .cancel) { pendingRevokeKey = nil }
        } message: {
            Text("Key bị thu hồi sẽ không thể xác thực được nữa.")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateApiKeyView(service: service, availableScopes: scopes) {
                Task { await load() }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func keyRow(_ key: ApiKeyInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.name).font(.headline)
                Spacer()
                statusBadge(key)
            }
            if let prefix = key.prefix, !prefix.isEmpty {
                Text("\(prefix)…")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let scopes = key.scopes, !scopes.isEmpty {
                Text(scopes.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let createdAt = key.createdAt, !createdAt.isEmpty {
                Text("Tạo: \(createdAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(_ key: ApiKeyInfo) -> some View {
        let revoked = isRevoked(key)
        Text(revoked ? "Đã thu hồi" : "Hoạt động")
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((revoked ? Color.secondary : Color.green).opacity(0.18), in: Capsule())
            .foregroundStyle(revoked ? Color.secondary : Color.green)
    }

    private func isRevoked(_ key: ApiKeyInfo) -> Bool {
        (key.status ?? "").lowercased() == "revoked"
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await service.listKeys()
            keys = response.keys
            scopes = response.scopes
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    private func revoke(_ key: ApiKeyInfo) {
        errorMessage = nil
        Task {
            do {
                try await service.revokeKey(id: key.id)
                await load()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
        }
    }

    private func delete(_ key: ApiKeyInfo) {
        errorMessage = nil
        Task {
            do {
                try await service.deleteKey(id: key.id)
                await load()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Create sheet

/// Sheet for creating a new API key. The plaintext `key` is shown exactly once after creation.
struct CreateApiKeyView: View {
    let service: SettingsService
    var availableScopes: [OfferedScope] = []
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedScopes: Set<String> = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var created: CreatedKey?
    @State private var didCopy = false

    private var canSubmit: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let scopesValid = availableScopes.isEmpty || !selectedScopes.isEmpty
        return !isCreating && hasName && scopesValid
    }

    var body: some View {
        NavigationStack {
            Form {
                if let created {
                    Section {
                        Text("Chỉ hiển thị một lần — hãy sao chép ngay. Bộ nhớ tạm sẽ tự xóa sau 60 giây.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Text(created.key)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.setItems(
                                [[UIPasteboard.typeAutomatic: created.key]],
                                options: [
                                    .localOnly: true,
                                    .expirationDate: Date().addingTimeInterval(60),
                                ]
                            )
                            didCopy = true
                        } label: {
                            Label(didCopy ? "Đã sao chép" : "Sao chép",
                                  systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        }
                    } header: {
                        Text("API key mới: \(created.name)")
                    }

                    Section {
                        Button("Xong") {
                            onFinished()
                            dismiss()
                        }
                    }
                } else {
                    Section("Tên key") {
                        TextField("Ví dụ: MacBook cá nhân", text: $name)
                            .autocorrectionDisabled()
                            .disabled(isCreating)
                    }

                    if !availableScopes.isEmpty {
                        Section {
                            ForEach(availableScopes) { scope in
                                Toggle(isOn: Binding(
                                    get: { selectedScopes.contains(scope.value) },
                                    set: { isOn in
                                        if isOn {
                                            selectedScopes.insert(scope.value)
                                        } else {
                                            selectedScopes.remove(scope.value)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scope.label).font(.subheadline)
                                        Text(scope.endpoints)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(isCreating)
                            }
                        } header: {
                            Text("Phạm vi truy cập")
                        } footer: {
                            if selectedScopes.isEmpty {
                                Text("Chọn ít nhất một phạm vi truy cập.")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }

                    Section {
                        Button {
                            create()
                        } label: {
                            HStack {
                                if isCreating { ProgressView().padding(.trailing, 4) }
                                Text("Tạo key")
                            }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
            .navigationTitle("Tạo API key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        if created != nil { onFinished() }
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating || created != nil)
            .onAppear {
                if selectedScopes.isEmpty && !availableScopes.isEmpty {
                    selectedScopes = Set(availableScopes.map(\.value))
                }
            }
        }
    }

    private func create() {
        guard canSubmit else { return }
        isCreating = true
        errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scopesArg: [String]? = availableScopes.isEmpty
            ? nil
            : availableScopes.map(\.value).filter { selectedScopes.contains($0) }
        Task {
            do {
                created = try await service.createKey(name: trimmed, scopes: scopesArg)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isCreating = false
        }
    }
}
