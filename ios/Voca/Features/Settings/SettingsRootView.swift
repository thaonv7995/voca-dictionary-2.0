import SwiftUI

/// Root of the Settings screen: appearance/theme, study UX, AI (LLM) + TTS connection config, and API-key management.
/// Set `embeddedInNavigation = true` when pushing from `ProfileView`'s `NavigationStack`.
struct SettingsRootView: View {
    var embeddedInNavigation: Bool = false

    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner
    private let service = SettingsService()

    private enum SaveStatus {
        case success(String)
        case failure(String)
    }

    @State private var showServerConfig = false
    @State private var showAudioCacheSheet = false
    @State private var prefetch = AudioPrefetchManager.shared
    @State private var vocabMeta = AppCache.cardsMetadata()

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
        if embeddedInNavigation {
            settingsForm
        } else {
            NavigationStack {
                settingsForm
            }
        }
    }

    private var settingsForm: some View {
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

            appearanceSection

            studyUxSection

            llmSection

            ttsSection

            cacheSection

            Section("API keys") {
                NavigationLink {
                    ApiKeysView()
                } label: {
                    Label("Quản lý API keys", systemImage: "key.fill")
                }
            }

            Section("Máy chủ Voca (Backend)") {
                LabeledContent("Địa chỉ hiện tại", value: AppConfig.baseURL.absoluteString)
                LabeledContent("Loại", value: AppConfig.isCustomBaseURL ? "Tùy chỉnh" : "Mặc định")
                Button {
                    Haptics.impact(.light)
                    showServerConfig = true
                } label: {
                    Label("Đổi địa chỉ máy chủ", systemImage: "server.rack")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VocaThemeBackground())
        .navigationTitle("Cài đặt")
        .onAppear { refreshCacheSummary() }
        .task { await load() }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showAudioCacheSheet, onDismiss: { refreshCacheSummary() }) {
            AudioCacheSheet()
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        @Bindable var theme = theme
        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chế độ sáng / tối")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Chế độ hiển thị", selection: $theme.appearance) {
                    ForEach(VocaAppearance.allCases) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: theme.appearance) { _, _ in
                    Haptics.selection()
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bảng màu chủ đạo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(theme.palette.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(VocaPalette.allCases) { item in
                        let selected = theme.palette == item
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                theme.palette = item
                            }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.gradient)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if selected {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .shadow(color: item.primary.opacity(selected ? 0.35 : 0), radius: 5, y: 2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(item.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? item.primary.opacity(0.12) : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? item.primary : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)

            Toggle(isOn: $theme.hanziCalligraphic) {
                HStack(spacing: 10) {
                    Text("学")
                        .font(VocaTypography.hanziFont(size: 20, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 28, height: 28)
                        .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phông chữ Hán ngữ thư pháp")
                        Text("Dùng nét Songti thanh đậm cho chữ Hán")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: theme.hanziCalligraphic) { _, _ in
                Haptics.selection()
            }

            Toggle(isOn: $theme.hapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phản hồi rung (Haptics)")
                    Text("Rung nhẹ khi lật thẻ, chấm điểm và thao tác")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Giao diện & Chủ đề")
        } footer: {
            Text("Thay đổi áp dụng ngay lập tức trên toàn bộ ứng dụng iOS.")
        }
    }

    private var studyUxSection: some View {
        @Bindable var theme = theme
        @Bindable var learner = learner
        return Section("Trải nghiệm học tập") {
            Stepper(value: $learner.dailyGoal, in: 5...100, step: 5) {
                HStack {
                    Text("Mục tiêu hằng ngày")
                    Spacer()
                    Text("\(learner.dailyGoal) thẻ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }

            Toggle("Tự động phát âm khi lật thẻ", isOn: $theme.autoSpeakFlashcard)
            Toggle("Thẻ ngược (Nghĩa → Từ)", isOn: $theme.reverseFlashcardMode)
        }
    }

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

    private var cacheSection: some View {
        @Bindable var prefetch = prefetch
        return Section {
            LabeledContent(
                "Từ vựng đã cache",
                value: "\(vocabMeta.cardCount) thẻ · \(ByteCountFormatter.string(fromByteCount: vocabMeta.totalBytes, countStyle: .file))"
            )

            LabeledContent(
                "Audio đã lưu",
                value: "\(prefetch.cacheStats.fileCount) tệp · \(prefetch.cacheStats.formattedSize)"
            )

            Toggle("Tự cache audio khi tạo từ mới", isOn: $prefetch.autoCacheNewCards)

            if prefetch.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: prefetch.progress)
                        .tint(theme.palette.primary)
                    Text("Đang tải \(prefetch.processedCount)/\(prefetch.totalCount) audio (\(prefetch.threadCount) luồng)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Button {
                Haptics.impact(.light)
                showAudioCacheSheet = true
            } label: {
                HStack {
                    Label(
                        prefetch.isRunning ? "Xem tiến trình tải audio" : "Quản lý cache & tải nhiều luồng",
                        systemImage: prefetch.isRunning ? "arrow.down.circle.fill" : "internaldrive.fill"
                    )
                    Spacer()
                    Text("\(prefetch.threadCount) luồng")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Bộ nhớ đệm & Offline")
        } footer: {
            Text("Từ vựng, bảng ôn A4 và audio đã nghe hoặc tải sẵn được lưu trên máy để mở tức thì và tránh gọi lại TTS.")
        }
    }

    private func refreshCacheSummary() {
        vocabMeta = AppCache.cardsMetadata()
        let cachedCards = AppCache.loadCards()
        Task { await prefetch.refreshStats(cards: cachedCards) }
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
