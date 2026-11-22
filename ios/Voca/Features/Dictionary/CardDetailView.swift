import SwiftUI
import UIKit

/// Full detail of a single vocabulary card with themed surfaces, complete Chinese & English sections,
/// favorite bookmarking, clipboard copy, A4 study sheet, and card-scoped AI tutor.
struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(LocalLearnerStore.self) private var learner

    private let initialCard: Card
    var onDeleted: () -> Void = {}

    @State private var card: Card
    @State private var selectedLevel: CardLevel
    @State private var isUpdatingLevel = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var showAgent = false
    @State private var showA4Sheet = false
    @State private var toastMessage: String?
    @State private var errorMessage: String?

    private let cards = CardsService()

    init(card: Card, onDeleted: @escaping () -> Void = {}) {
        self.initialCard = card
        _card = State(initialValue: card)
        _selectedLevel = State(initialValue: CardLevel(card.level) ?? .new)
        self.onDeleted = onDeleted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VocaThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if card.isChinese {
                        chineseContent
                    } else {
                        levelCard
                        englishContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .brandCard(padding: 12, cornerRadius: 14)
                    }

                    deleteButton
                }
                .padding()
                .frame(
                    maxWidth: horizontalSizeClass == .regular ? (card.isChinese ? 1080 : 760) : .infinity,
                    alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            if let toastMessage {
                VocaToastBanner(icon: "checkmark.circle.fill", message: toastMessage)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(card.word)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Haptics.selection()
                    let isFav = learner.toggleFavorite(card.slug)
                    showToast(isFav ? "Đã thêm vào Yêu thích" : "Đã bỏ khỏi Yêu thích")
                } label: {
                    Image(systemName: learner.isFavorite(card.slug) ? "star.fill" : "star")
                        .foregroundStyle(learner.isFavorite(card.slug) ? .orange : Brand.green)
                        .symbolEffect(.bounce, value: learner.isFavorite(card.slug))
                }
                .accessibilityLabel(learner.isFavorite(card.slug) ? "Bỏ yêu thích" : "Yêu thích")

                Button {
                    copyCardSummary()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("Sao chép từ")
            }
        }
        .sheet(isPresented: $showAgent) {
            CardAgentView(card: card)
        }
        .sheet(isPresented: $showA4Sheet) {
            A4SheetView(card: card)
        }
        .onChange(of: initialCard) { _, updated in
            card = updated
            selectedLevel = CardLevel(updated.level) ?? .new
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(card.isChinese
                          ? VocaTypography.hanziFont(size: 52, weight: .bold, isCalligraphic: ThemeStore.shared.hanziCalligraphic)
                          : .system(size: 36, weight: .bold, design: .rounded))
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                LevelBadge(level: selectedLevel)
            }

            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(card.isChinese ? .title3.weight(.medium) : .system(.title3, design: .monospaced))
                    .foregroundStyle(card.isChinese ? Brand.green : .secondary)
                    .textSelection(.enabled)
            }

            if !card.isChinese, let pronunciation = card.pronunciation, !pronunciation.isEmpty,
               normalizedTranscription(pronunciation) != normalizedTranscription(card.ipa ?? "") {
                Text(pronunciation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !card.isChinese && hasMeta {
                HStack(spacing: 8) {
                    if let pos = card.partOfSpeech, !pos.isEmpty { metaChip(pos) }
                    if let topic = card.topic, !topic.isEmpty { Badge(text: topic) }
                }
            }

            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandHeroCard(padding: 18, cornerRadius: 22)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            PronounceButton(
                text: card.word,
                language: card.cardLanguage,
                size: 40,
                font: .title3,
                tintedCapsule: true
            )
            askAIButton
            if card.isChinese {
                a4SheetButton
            }
        }
        .padding(.top, 2)
    }

    private var a4SheetButton: some View {
        Button {
            showA4Sheet = true
        } label: {
            Label("Phiếu A4", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(Brand.green)
    }

    private var askAIButton: some View {
        Button {
            showAgent = true
        } label: {
            Label("Hỏi AI", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.green)
    }

    private var hasMeta: Bool {
        !(card.partOfSpeech ?? "").isEmpty || !(card.topic ?? "").isEmpty
    }

    // MARK: - Level

    private var levelCard: some View {
        HStack {
            Label("Cấp độ ghi nhớ", systemImage: "chart.bar.fill")
                .font(.headline)
            Spacer()
            if isUpdatingLevel { ProgressView().controlSize(.small) }
            Picker("Cấp độ", selection: $selectedLevel) {
                ForEach(CardLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.menu)
            .disabled(isUpdatingLevel)
            .onChange(of: selectedLevel) { _, newValue in
                updateLevel(to: newValue)
            }
            .tint(selectedLevel.tint)
        }
        .brandCard()
    }

    // MARK: - English Content

    @ViewBuilder private var englishContent: some View {
        if let text = card.meaningEn, !text.isEmpty {
            section("Nghĩa (EN)", text: text, icon: "textformat")
        }
        if let text = card.meaningVi, !text.isEmpty {
            section("Nghĩa (VI)", text: text, icon: "character.book.closed")
        }
        examplesSection
        useCasesSection
        if let text = card.memoryTip, !text.isEmpty {
            section("Mẹo ghi nhớ", text: text, icon: "lightbulb.fill", iconTint: .orange)
        }
        if let text = card.toeicTrap, !text.isEmpty {
            section("Bẫy IELTS", text: text, icon: "exclamationmark.triangle.fill", iconTint: .red)
        }
        tagsSection
    }

    // MARK: - Chinese Content (complete: stroke writing, info, ALL examples, tips, use cases & tags)

    @ViewBuilder private var chineseContent: some View {
        if horizontalSizeClass == .regular {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    HanziWritingView(word: card.word)
                        .frame(minWidth: 360, maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 16) {
                        chineseInfoCard
                        chineseExamplesCard
                    }
                    .frame(width: 400)
                }

                VStack(alignment: .leading, spacing: 18) {
                    HanziWritingView(word: card.word)
                    chineseInfoCard
                    chineseExamplesCard
                }
            }
        } else {
            HanziWritingView(word: card.word)
            chineseInfoCard
            chineseExamplesCard
        }

        useCasesSection
        if let text = card.memoryTip, !text.isEmpty {
            section("Mẹo ghi nhớ", text: text, icon: "lightbulb.fill", iconTint: .orange)
        }
        tagsSection
    }

    private var chineseInfoCard: some View {
        let hasMeaning = !(card.meaningVi ?? "").isEmpty
        let hasChips = !(card.partOfSpeech ?? "").isEmpty || !(card.topic ?? "").isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            if let meaning = card.meaningVi, !meaning.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    VocaIconBadge(systemImage: "character.book.closed.fill", size: 34, iconSize: 15)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nghĩa tiếng Việt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(meaning)
                            .font(.title3.weight(.semibold))
                    }
                }
            }

            if hasMeaning {
                Divider().opacity(0.6)
            }

            if hasChips {
                VocaFlowLayout(spacing: 8) {
                    if let pos = card.partOfSpeech, !pos.isEmpty { metaChip(pos) }
                    if let topic = card.topic, !topic.isEmpty { Badge(text: topic) }
                }
            }

            HStack(spacing: 8) {
                Label("Cấp độ ghi nhớ", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if isUpdatingLevel { ProgressView().controlSize(.small) }
                Picker("Cấp độ", selection: $selectedLevel) {
                    ForEach(CardLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isUpdatingLevel)
                .onChange(of: selectedLevel) { _, newValue in updateLevel(to: newValue) }
                .tint(selectedLevel.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    @ViewBuilder private var chineseExamplesCard: some View {
        let examples = (card.examples ?? []).filter { !$0.isEmpty }
        if !examples.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Ví dụ", icon: "text.quote")

                ForEach(Array(examples.enumerated()), id: \.offset) { index, raw in
                    let example = ChineseExample(raw)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(example.hanzi)
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                            PronounceButton(text: example.hanzi, language: .chinese, size: 30, font: .subheadline, tintedCapsule: true)
                                .id("zh-ex-\(index)-\(example.hanzi)")
                        }
                        if let pinyin = example.pinyin {
                            Text(pinyin)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Brand.green)
                                .textSelection(.enabled)
                        }
                        if let meaning = example.meaningVi {
                            Text(meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if index < examples.count - 1 {
                        Divider().opacity(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    @ViewBuilder private var examplesSection: some View {
        let examples = (card.examples ?? []).filter { !$0.isEmpty }
        if !examples.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Ví dụ", icon: "text.quote")
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    let spoken = card.isChinese ? ChineseExample(example).hanzi : example
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Brand.green)
                        Text(example)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        PronounceButton(text: spoken, language: card.cardLanguage, size: 28, font: .footnote, tintedCapsule: true)
                            .id("en-ex-\(index)-\(spoken)")
                    }
                    if index < examples.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    @ViewBuilder private var useCasesSection: some View {
        let useCases = Self.uniqueNonEmpty(card.useCases)
        if !useCases.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Cách dùng", icon: "list.bullet")
                ForEach(useCases, id: \.self) { useCase in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Brand.green)
                        Text(useCase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    @ViewBuilder private var tagsSection: some View {
        let tags = Self.uniqueNonEmpty(card.tags)
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Thẻ", icon: "tag")
                VocaFlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { metaChip($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    private static func uniqueNonEmpty(_ items: [String]?) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in items ?? [] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                if isDeleting { ProgressView().controlSize(.small) }
                Label("Xóa thẻ", systemImage: "trash")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(isDeleting)
        .confirmationDialog(
            "Xóa thẻ “\(card.word)”?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xóa", role: .destructive) { deleteCard() }
            Button("Hủy", role: .cancel) {}
        }
    }

    // MARK: - Reusable bits

    private func sectionHeader(_ title: String, icon: String? = nil, tint: Color? = nil) -> some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(tint ?? Brand.green)
            }
            Text(title)
        }
        .font(.headline)
    }

    private func section(_ title: String, text: String, icon: String? = nil, iconTint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title, icon: icon, tint: iconTint)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .brandCard()
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Actions

    private func copyCardSummary() {
        var parts = [card.word]
        if let phonetic = card.phonetic { parts.append(phonetic) }
        if let meaning = card.meaningVi, !meaning.isEmpty { parts.append("— \(meaning)") }
        UIPasteboard.general.string = parts.joined(separator: " ")
        Haptics.impact(.light)
        showToast("Đã sao chép “\(card.word)”")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastMessage = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    if toastMessage == text { toastMessage = nil }
                }
            }
        }
    }

    private func updateLevel(to newValue: CardLevel) {
        let currentLevel = CardLevel(card.level) ?? .new
        guard currentLevel != newValue else { return }
        isUpdatingLevel = true
        errorMessage = nil
        Haptics.selection()
        Task {
            do {
                card = try await cards.setLevel(slug: card.slug, level: newValue.rawValue)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                selectedLevel = CardLevel(card.level) ?? .new
            }
            isUpdatingLevel = false
        }
    }

    private func deleteCard() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await cards.delete(slug: card.slug)
                Haptics.notify(.warning)
                onDeleted()
                dismiss()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                isDeleting = false
            }
        }
    }
}

fileprivate func normalizedTranscription(_ raw: String) -> String {
    raw.lowercased().filter { !"/[]() \t\n".contains($0) }
}
