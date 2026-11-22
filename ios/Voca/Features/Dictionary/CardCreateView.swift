import SwiftUI

/// Sheet that creates a new card from a single word via the server-side LLM, plus quick photo OCR launch.
struct CardCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    var onCreated: () -> Void = {}

    @State private var word = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showScan = false
    @State private var createTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private let cards = CardsService()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var canSubmit: Bool {
        !isCreating && !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        CardLanguagePicker(selection: $languageRaw)
                            .disabled(isCreating)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                VocaIconBadge(systemImage: "wand.and.stars", size: 38, iconSize: 17)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tạo thẻ bằng AI")
                                        .font(.headline)
                                    Text(language == .chinese
                                         ? "Tự tạo Pinyin, nghĩa Việt và ví dụ song ngữ"
                                         : "Tự tạo IPA, nghĩa Anh/Việt, ví dụ & mẹo ghi nhớ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            TextField(
                                language == .chinese ? "Nhập Hán tự (ví dụ: 坚持)" : "Nhập từ vựng (ví dụ: resilient)",
                                text: $word
                            )
                            .font(language == .chinese ? .title3.weight(.semibold) : .body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($fieldFocused)
                            .disabled(isCreating)
                            .onSubmit { if canSubmit { create() } }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Brand.elevatedFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(fieldFocused ? Brand.green : Brand.hairlineBorder(for: colorScheme), lineWidth: fieldFocused ? 1.5 : 1)
                            )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            Button(action: create) {
                                HStack(spacing: 8) {
                                    if isCreating { ProgressView().tint(.white) }
                                    Text(isCreating ? "Đang tạo…" : "Tạo thẻ bằng AI")
                                }
                            }
                            .buttonStyle(BrandCTAButtonStyle())
                            .disabled(!canSubmit)
                        }
                        .brandCard()

                        Button {
                            showScan = true
                        } label: {
                            HStack(spacing: 12) {
                                VocaIconBadge(systemImage: "camera.viewfinder", tint: .indigo, size: 42, iconSize: 19)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Quét ảnh tạo nhiều thẻ")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Chụp hoặc chọn ảnh sách/bảng để nhận diện từ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .brandCard()
                        }
                        .buttonStyle(.plain)
                        .disabled(isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle("Tạo thẻ mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        createTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear { fieldFocused = true }
            .onDisappear { createTask?.cancel() }
            .sheet(isPresented: $showScan) {
                ScanWordsView(language: language) {
                    onCreated()
                    dismiss()
                }
            }
        }
    }

    private func create() {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCreating else { return }
        isCreating = true
        errorMessage = nil
        Haptics.impact(.light)
        let targetLanguage = language
        createTask = Task {
            do {
                let created = try await cards.createWithAI(word: trimmed, language: targetLanguage)
                guard !Task.isCancelled else { return }
                AudioPrefetchManager.shared.cacheCardInBackgroundIfEnabled(created)
                Haptics.notify(.success)
                onCreated()
                dismiss()
            } catch is CancellationError {
                isCreating = false
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                Haptics.notify(.error)
                isCreating = false
            }
        }
    }
}
