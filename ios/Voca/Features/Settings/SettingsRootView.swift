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
    @AppStorage(VoiceSettingsStore.useDeviceSpeechDefaultsKey) private var useDeviceSpeech = false
    @State private var ttsBaseUrl = ""
    @State private var ttsModel = UserVoices.defaultEnglishModel
    @State private var chineseTtsModel = UserVoices.defaultChineseModel
    @State private var voiceA = UserVoices.defaultEnglishSpeakers[0]
    @State private var voiceB = UserVoices.defaultEnglishSpeakers[1]
    @State private var voiceC = UserVoices.defaultEnglishSpeakers[2]
    @State private var chineseVoiceA = UserVoices.defaultChineseSpeakers[0]
    @State private var chineseVoiceB = UserVoices.defaultChineseSpeakers[1]
    @State private var chineseVoiceC = UserVoices.defaultChineseSpeakers[2]
    @State private var autoSelectVoices = true
    @State private var ttsApiKey = ""
    @State private var hasTtsKey = false
    @State private var isSavingTts = false
    @State private var isTestingTts = false
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

                Section("Máy chủ Voca (Backend)") {
                    LabeledContent("Địa chỉ hiện tại", value: AppConfig.baseURL.absoluteString)
                    LabeledContent("Loại", value: AppConfig.isCustomBaseURL ? "Tùy chỉnh" : "Mặc định")
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
            Toggle("Dùng giọng đọc của máy", isOn: $useDeviceSpeech)

            if useDeviceSpeech {
                Text("Phát âm từ vựng, ví dụ và hội thoại trực tiếp bằng giọng đọc tích hợp trên máy, không gọi lên máy chủ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("Tiếng Trung") {
                    Text(AudioPlayer.preferredDeviceVoiceSummary(for: .chinese))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Tiếng Anh") {
                    Text(AudioPlayer.preferredDeviceVoiceSummary(for: .english))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ttsTestButtons

                Text("Mẹo: Vào Cài đặt iPhone → Trợ năng → Nội dung được đọc → Giọng nói để tải giọng Enhanced / Premium.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DisclosureGroup("Cấu hình TTS máy chủ (đang tắt)") {
                    serverTtsControls
                    saveTtsButton
                    statusRow(ttsStatus)
                }
            } else {
                serverTtsControls
                ttsTestButtons
                saveTtsButton
                statusRow(ttsStatus)
            }
        }
    }

    @ViewBuilder
    private var serverTtsControls: some View {
        TextField("Base URL", text: $ttsBaseUrl)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)

        voiceFieldRow(
            label: "Giọng tiếng Trung",
            text: $chineseTtsModel,
            presets: VoicePreset.chinese
        )

        voiceFieldRow(
            label: "Giọng tiếng Anh",
            text: $ttsModel,
            presets: VoicePreset.english
        )

        DisclosureGroup("Giọng hội thoại (A / B / C)") {
            Toggle("AI tự chọn giọng phù hợp", isOn: $autoSelectVoices)

            voiceFieldRow(label: "Tiếng Trung · A", text: $chineseVoiceA, presets: VoicePreset.chinese)
            voiceFieldRow(label: "Tiếng Trung · B", text: $chineseVoiceB, presets: VoicePreset.chinese)
            voiceFieldRow(label: "Tiếng Trung · C", text: $chineseVoiceC, presets: VoicePreset.chinese)

            voiceFieldRow(label: "Tiếng Anh · A", text: $voiceA, presets: VoicePreset.english)
            voiceFieldRow(label: "Tiếng Anh · B", text: $voiceB, presets: VoicePreset.english)
            voiceFieldRow(label: "Tiếng Anh · C", text: $voiceC, presets: VoicePreset.english)
        }

        SecureField("••• để trống nếu không đổi", text: $ttsApiKey)

        LabeledContent("Khóa API") {
            Text(hasTtsKey ? "Đã cấu hình khóa" : "Chưa có khóa")
                .foregroundStyle(hasTtsKey ? Color.green : Color.secondary)
        }
    }

    private var ttsTestButtons: some View {
        HStack(spacing: 12) {
            Button {
                testVoice(
                    text: "你好，这是中文语音测试。",
                    language: .chinese,
                    voiceModel: chineseTtsModel
                )
            } label: {
                Label("Thử Tiếng Trung", systemImage: "speaker.wave.2")
            }
            .disabled(isTestingTts)

            Spacer()

            Button {
                testVoice(
                    text: "Hello, this is a voice test.",
                    language: .english,
                    voiceModel: ttsModel
                )
            } label: {
                Label("Thử Tiếng Anh", systemImage: "speaker.wave.2")
            }
            .disabled(isTestingTts)
        }
    }

    private var saveTtsButton: some View {
        Button {
            saveTts()
        } label: {
            HStack {
                if isSavingTts { ProgressView().padding(.trailing, 4) }
                Text("Lưu")
            }
        }
        .disabled(isSavingTts || isLoading)
    }

    private func voiceFieldRow(label: String, text: Binding<String>, presets: [(id: String, label: String)]) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Menu {
                ForEach(presets, id: \.id) { item in
                    Button(item.label) { text.wrappedValue = item.id }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Brand.green)
                    .imageScale(.large)
            }
        }
    }

    private func testVoice(text: String, language: CardLanguage, voiceModel: String) {
        isTestingTts = true
        ttsStatus = nil
        let clean = voiceModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let forceLocal = useDeviceSpeech
        Task {
            do {
                try await TTSService().speak(
                    text,
                    language: language,
                    voiceModel: clean.isEmpty ? nil : clean,
                    fallbackToSystem: forceLocal,
                    forceSystem: forceLocal
                )
            } catch {
                ttsStatus = .failure((error as? ApiError)?.message ?? error.localizedDescription)
            }
            isTestingTts = false
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
        let loadedEnglish = (s.ttsModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        ttsModel = loadedEnglish.isEmpty ? UserVoices.defaultEnglishModel : loadedEnglish
        let loadedChinese = (s.voices?.chineseModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        chineseTtsModel = loadedChinese.isEmpty
            ? (VoiceSettingsStore.isChineseVoice(loadedEnglish) ? loadedEnglish : UserVoices.defaultChineseModel)
            : loadedChinese
        voiceA = nonEmpty(s.voices?.a) ?? UserVoices.defaultEnglishSpeakers[0]
        voiceB = nonEmpty(s.voices?.b) ?? UserVoices.defaultEnglishSpeakers[1]
        voiceC = nonEmpty(s.voices?.c) ?? UserVoices.defaultEnglishSpeakers[2]
        chineseVoiceA = nonEmpty(s.voices?.chineseA) ?? UserVoices.defaultChineseSpeakers[0]
        chineseVoiceB = nonEmpty(s.voices?.chineseB) ?? UserVoices.defaultChineseSpeakers[1]
        chineseVoiceC = nonEmpty(s.voices?.chineseC) ?? UserVoices.defaultChineseSpeakers[2]
        autoSelectVoices = s.voices?.autoSelect ?? true
        hasTtsKey = s.hasTtsKey
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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
                    ttsModel: nil,
                    voices: nil
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
        let voices = UserVoices(
            a: voiceA,
            b: voiceB,
            c: voiceC,
            chineseModel: chineseTtsModel,
            chineseA: chineseVoiceA,
            chineseB: chineseVoiceB,
            chineseC: chineseVoiceC,
            autoSelect: autoSelectVoices
        )
        Task {
            do {
                let body = UpdateSettingsBody(
                    llmBaseUrl: nil,
                    llmApiKey: nil,
                    llmModel: nil,
                    ttsBaseUrl: ttsBaseUrl,
                    ttsApiKey: keyOrNil,
                    ttsModel: ttsModel,
                    voices: voices
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
