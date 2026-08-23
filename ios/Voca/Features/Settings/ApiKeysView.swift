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
                                Button("Xóa", role: .destructive) { delete(key) }
                                if !isRevoked(key) {
                                    Button("Thu hồi") { revoke(key) }.tint(.orange)
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
        .sheet(isPresented: $showCreateSheet) {
            CreateApiKeyView(service: service) {
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
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var created: CreatedKey?
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            Form {
                if let created {
                    Section {
                        Text("Chỉ hiển thị một lần — hãy sao chép ngay.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Text(created.key)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = created.key
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
                        .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                }
            }
            .interactiveDismissDisabled(created != nil)
        }
    }

    private func create() {
        isCreating = true
        errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                created = try await service.createKey(name: trimmed)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isCreating = false
        }
    }
}
