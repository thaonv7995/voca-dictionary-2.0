import SwiftUI

/// Dedicated sheet for managing offline vocabulary sync and multi-threaded batch TTS audio caching.
struct AudioCacheSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeStore.self) private var theme

    var initialCards: [Card] = []

    @State private var prefetch = AudioPrefetchManager.shared
    @State private var vocabMeta = AppCache.cardsMetadata()
    @State private var isSyncingVocab = false
    @State private var vocabSyncMessage: String?
    @State private var vocabSyncIsError = false
    @State private var showClearConfirm = false

    private let threadChoices = [2, 4, 6]

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        audioHeroCard
                        if VoiceSettingsStore.shared.useDeviceSpeech {
                            deviceSpeechNoteCard
                        }
                        if prefetch.isRunning || prefetch.processedCount > 0 {
                            progressCard
                        }
                        configurationCard
                        actionButtons
                        vocabularyCacheCard
                    }
                    .padding()
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Cache Từ vựng & Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                vocabMeta = AppCache.cardsMetadata()
                let cards = initialCards.isEmpty ? AppCache.loadCards() : initialCards
                await prefetch.refreshStats(cards: cards)
            }
            .task(id: "cache-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                    await AppCache.waitForPendingDiskWrites()
                    vocabMeta = AppCache.cardsMetadata()
                }
            }
            .onChange(of: prefetch.languageScope) { _, _ in
                Task { await prefetch.refreshStats(cards: effectiveCards) }
            }
            .onChange(of: prefetch.includeExamples) { _, _ in
                Task { await prefetch.refreshStats(cards: effectiveCards) }
            }
            .alert("Xóa bộ nhớ đệm audio?", isPresented: $showClearConfirm) {
                Button("Xóa (\(prefetch.cacheStats.formattedSize))", role: .destructive) {
                    Haptics.notify(.warning)
                    Task {
                        await prefetch.clearAudioCache(cards: effectiveCards)
                    }
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Thao tác này xóa \(prefetch.cacheStats.fileCount) tệp âm thanh đã lưu trên máy. Từ vựng vẫn được giữ nguyên.")
            }
        }
    }

    private var effectiveCards: [Card] {
        let cached = AppCache.loadCards()
        return cached.isEmpty ? initialCards : cached
    }

    // MARK: - Cards

    private var audioHeroCard: some View {
        let total = prefetch.coverage.total
        let cached = prefetch.coverage.cached
        let fraction = total > 0 ? Double(cached) / Double(total) : 0
        let percent = Int((fraction * 100).rounded())

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(theme.accentSoft, lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: min(1, max(0, fraction)))
                        .stroke(theme.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: fraction)
                    Text("\(percent)%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bộ nhớ đệm Audio TTS")
                        .font(.headline)
                    Text("\(cached)/\(total) mục trong phạm vi đã sẵn sàng offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    HStack(spacing: 8) {
                        VocaPillBadge(
                            text: "\(prefetch.cacheStats.fileCount) tệp MP3",
                            icon: "waveform",
                            tint: theme.accent
                        )
                        VocaPillBadge(
                            text: prefetch.cacheStats.formattedSize,
                            icon: "internaldrive.fill",
                            tint: .indigo
                        )
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
        .brandHeroCard(padding: 18, cornerRadius: 20)
    }

    private var deviceSpeechNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
                .font(.body)
            Text("Đang bật “Dùng giọng đọc của máy”. Audio tải về vẫn được lưu an toàn trên máy để phát ngay tức thì (không tốn lượt gọi TTS server) khi bạn chuyển lại giọng AI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(padding: 14, cornerRadius: 16)
    }

    private var progressCard: some View {
        let pct = Int((prefetch.progress * 100).rounded())

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if prefetch.isRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.accent)
                        Text("Đang tải đa luồng (\(prefetch.threadCount) luồng)…")
                            .font(.subheadline.weight(.semibold))
                    }
                } else if prefetch.wasCancelled {
                    Label("Đã dừng tải cache audio", systemImage: "stop.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label(
                        prefetch.failedCount == 0 ? "Hoàn tất tải cache audio" : "Đã tải xong (có \(prefetch.failedCount) lỗi)",
                        systemImage: prefetch.failedCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(prefetch.failedCount == 0 ? Brand.semanticSuccess : .orange)
                }
                Spacer()
                Text("\(prefetch.processedCount)/\(prefetch.totalCount) · \(pct)%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
            }

            ProgressView(value: prefetch.progress)
                .tint(theme.accent)
                .animation(.easeInOut(duration: 0.2), value: prefetch.progress)

            if prefetch.isRunning, !prefetch.currentSampleText.isEmpty {
                Text("Đang xử lý: \(prefetch.currentSampleText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                statChip(title: "Có sẵn", value: "\(prefetch.cachedHitCount)", tint: .secondary)
                statChip(title: "Mới tải", value: "\(prefetch.downloadedCount)", tint: Brand.semanticSuccess)
                if prefetch.downloadedBytes > 0 {
                    statChip(
                        title: "Dung lượng",
                        value: ByteCountFormatter.string(fromByteCount: prefetch.downloadedBytes, countStyle: .file),
                        tint: theme.accent
                    )
                }
                if prefetch.failedCount > 0 {
                    statChip(title: "Lỗi", value: "\(prefetch.failedCount)", tint: .red)
                }
            }

            if let lastError = prefetch.lastError, !lastError.isEmpty {
                Text("Lỗi gần nhất: \(lastError)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .brandCard(padding: 16, cornerRadius: 18)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var configurationCard: some View {
        @Bindable var bindable = prefetch

        return VStack(alignment: .leading, spacing: 14) {
            Text("Tùy chọn tải đa luồng")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Phạm vi tải")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Phạm vi", selection: $bindable.languageScope) {
                    ForEach(PrefetchLanguageScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(prefetch.isRunning)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Số luồng tải song song")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(prefetch.threadCount) luồng")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
                Picker("Số luồng", selection: $bindable.threadCount) {
                    ForEach(threadChoices, id: \.self) { count in
                        Text("\(count) luồng").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(prefetch.isRunning)
                Text("Tải song song giúp nhanh hơn nhưng không quá tải server TTS. Mặc định: 4 luồng.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.6)

            Toggle(isOn: $bindable.includeExamples) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bao gồm câu ví dụ")
                        .font(.subheadline)
                    Text("Tải sẵn cả audio các câu ví dụ trong mỗi thẻ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)
            .disabled(prefetch.isRunning)

            Divider().opacity(0.6)

            Toggle(isOn: $bindable.autoCacheNewCards) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tự động cache audio từ mới")
                        .font(.subheadline)
                    Text("Tải âm thanh nền ngay sau khi tạo từ mới bằng AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)
        }
        .brandCard(padding: 16, cornerRadius: 18)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if prefetch.isRunning {
                Button(role: .destructive) {
                    Haptics.impact(.medium)
                    prefetch.cancel()
                } label: {
                    Label("Dừng tải audio", systemImage: "stop.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PressableScaleStyle(scale: 0.97))
            } else {
                let remaining = max(0, prefetch.coverage.total - prefetch.coverage.cached)
                let title: String = {
                    if prefetch.coverage.total == 0 { return "Tải tất cả audio về máy" }
                    if remaining == 0 { return "Đã cache đủ (\(prefetch.coverage.total)/\(prefetch.coverage.total)) · Kiểm tra lại" }
                    return "Tải \(remaining) audio về máy (\(prefetch.threadCount) luồng)"
                }()

                Button {
                    Haptics.impact(.medium)
                    prefetch.start(cards: effectiveCards)
                } label: {
                    Label(title, systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(BrandCTAButtonStyle())
                .disabled(isSyncingVocab)
            }

            if prefetch.cacheStats.fileCount > 0 && !prefetch.isRunning {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Xóa bộ nhớ đệm audio (\(prefetch.cacheStats.formattedSize))", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.red)
                        .background(
                            Color.red.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var vocabularyCacheCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VocaIconBadge(systemImage: "books.vertical.fill", tint: .teal, size: 36, iconSize: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cache Từ vựng offline")
                        .font(.headline)
                    Text("\(vocabMeta.cardCount) thẻ · \(ByteCountFormatter.string(fromByteCount: vocabMeta.totalBytes, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let savedAt = vocabMeta.savedAt {
                Text("Đồng bộ lần cuối: \(savedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let vocabSyncMessage {
                Text(vocabSyncMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(vocabSyncIsError ? Color.red : theme.accent)
            }

            Button {
                syncVocabulary()
            } label: {
                HStack(spacing: 8) {
                    if isSyncingVocab { ProgressView().controlSize(.small) }
                    Label("Đồng bộ toàn bộ kho từ ngay", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)
            .disabled(isSyncingVocab || prefetch.isRunning)
        }
        .brandCard(padding: 16, cornerRadius: 18)
    }

    // MARK: - Helpers

    private func statChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Brand.elevatedFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func syncVocabulary() {
        isSyncingVocab = true
        vocabSyncMessage = nil
        vocabSyncIsError = false
        Haptics.impact(.light)
        Task {
            do {
                let fresh = try await CardsService().list()
                await AppCache.waitForPendingDiskWrites()
                vocabMeta = AppCache.cardsMetadata()
                await prefetch.refreshStats(cards: fresh)
                Haptics.notify(.success)
                vocabSyncIsError = false
                vocabSyncMessage = "Đã đồng bộ và lưu \(fresh.count) thẻ từ vựng."
            } catch {
                Haptics.notify(.error)
                vocabSyncIsError = true
                vocabSyncMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
            isSyncingVocab = false
        }
    }
}
