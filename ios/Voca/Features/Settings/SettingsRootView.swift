import SwiftUI

/// Root of the Settings tab: AI (LLM) + TTS connection config and API-key management.
/// Self-contained (owns its `NavigationStack`) so it can be dropped straight into a `TabView`.
struct SettingsRootView: View {
    private let service = SettingsService()

    private enum SaveStatus {
        case success(String)
        case failure(String)
    }

    // LLM
    @State private var llmBaseUrl = ""
    @State private var llmModel = ""
    @State private var llmApiKey = ""
    @State private var hasLlmKey = false
    @State private var isSavingLlm = false
    @State private var llmStatus: SaveStatus?

    // TTS
    @State private var ttsBaseUrl = ""
    @State private var ttsModel = ""
    @State private var ttsApiKey = ""
    @State private var hasTtsKey = false
    @State private var isSavingTts = false
    @State private var ttsStatus: SaveStatus?

    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("Đang tải cài đặt…").foregroundStyle(.secondary)
                        }
                    }
                }

                if let loadError {
                    Section { Text(loadError).foregroundStyle(.red) }
                }

                llmSection

                ttsSection

                Section("API keys") {
                    NavigationLink("Quản lý API keys") { ApiKeysView() }
                }
            }
            .navigationTitle("Cài đặt")
            .task { await load() }
        }
    }

    // MARK: - Sections

    private var llmSection: some View {
        Section("Kết nối AI (LLM)") {
            TextField("Base URL", text: $llmBaseUrl)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            TextField("Model", text: $llmModel)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("••• để trống nếu không đổi", text: $llmApiKey)

            LabeledContent("Khóa API") {
                Text(hasLlmKey ? "Đã cấu hình khóa" : "Chưa có khóa")
                    .foregroundStyle(hasLlmKey ? Color.green : Color.secondary)
            }

            Button {
                saveLlm()
            } label: {
                HStack {
                    if isSavingLlm { ProgressView().padding(.trailing, 4) }
                    Text("Lưu")
                }
            }
            .disabled(isSavingLlm || isLoading)

            statusRow(llmStatus)
        }
    }

    private var ttsSection: some View {
        Section("Giọng đọc (TTS)") {
            TextField("Base URL", text: $ttsBaseUrl)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            TextField("Model", text: $ttsModel)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("••• để trống nếu không đổi", text: $ttsApiKey)

            LabeledContent("Khóa API") {
                Text(hasTtsKey ? "Đã cấu hình khóa" : "Chưa có khóa")
                    .foregroundStyle(hasTtsKey ? Color.green : Color.secondary)
            }

            Button {
                saveTts()
            } label: {
                HStack {
                    if isSavingTts { ProgressView().padding(.trailing, 4) }
                    Text("Lưu")
                }
            }
            .disabled(isSavingTts || isLoading)

            statusRow(ttsStatus)
        }
    }

    @ViewBuilder
    private func statusRow(_ status: SaveStatus?) -> some View {
        if let status {
            switch status {
            case .success(let message):
                Text(message).font(.footnote).foregroundStyle(.green)
            case .failure(let message):
                Text(message).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            let settings = try await service.get()
            apply(settings)
        } catch {
            loadError = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    private func apply(_ s: UserSettings) {
        llmBaseUrl = s.llmBaseUrl ?? ""
        llmModel = s.llmModel ?? ""
        hasLlmKey = s.hasLlmKey
        ttsBaseUrl = s.ttsBaseUrl ?? ""
        ttsModel = s.ttsModel ?? ""
        hasTtsKey = s.hasTtsKey
    }

    private func saveLlm() {
        isSavingLlm = true
        llmStatus = nil
        let keyOrNil = llmApiKey.isEmpty ? nil : llmApiKey
        Task {
            do {
                let body = UpdateSettingsBody(
                    llmBaseUrl: llmBaseUrl,
                    llmApiKey: keyOrNil,
                    llmModel: llmModel,
                    ttsBaseUrl: nil,
                    ttsApiKey: nil,
                    ttsModel: nil
                )
                let updated = try await service.update(body)
                apply(updated)
                llmApiKey = ""
                llmStatus = .success("Đã lưu cấu hình LLM.")
            } catch {
                llmStatus = .failure((error as? ApiError)?.message ?? error.localizedDescription)
            }
            isSavingLlm = false
        }
    }

    private func saveTts() {
        isSavingTts = true
        ttsStatus = nil
        let keyOrNil = ttsApiKey.isEmpty ? nil : ttsApiKey
        Task {
            do {
                let body = UpdateSettingsBody(
                    llmBaseUrl: nil,
                    llmApiKey: nil,
                    llmModel: nil,
                    ttsBaseUrl: ttsBaseUrl,
                    ttsApiKey: keyOrNil,
                    ttsModel: ttsModel
                )
                let updated = try await service.update(body)
                apply(updated)
                ttsApiKey = ""
                ttsStatus = .success("Đã lưu cấu hình TTS.")
            } catch {
                ttsStatus = .failure((error as? ApiError)?.message ?? error.localizedDescription)
            }
            isSavingTts = false
        }
    }
}
