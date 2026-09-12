import SwiftUI

/// Full detail of a single card: meanings, examples, tips, pronunciation,
/// level control and delete. Keeps a local copy of the card so edits reflect immediately.
struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Called after the card is deleted (so the list can refresh).
    var onDeleted: () -> Void = {}

    @State private var card: Card
    @State private var selectedLevel: CardLevel
    @State private var isUpdatingLevel = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var showAgent = false
    @State private var errorMessage: String?

    private let cards = CardsService()

    init(card: Card, onDeleted: @escaping () -> Void = {}) {
        _card = State(initialValue: card)
        _selectedLevel = State(initialValue: CardLevel(card.level) ?? .new)
        self.onDeleted = onDeleted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if card.isChinese {
                    chineseContent
                } else {
                    levelSection
                    englishContent
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                deleteButton
            }
            .padding()
            .frame(
                maxWidth: horizontalSizeClass == .regular ? (card.isChinese ? 1080 : 760) : .infinity,
                alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(card.word)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAgent) {
            CardAgentView(card: card)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(card.isChinese ? .system(size: 52, weight: .bold) : .largeTitle.bold())
                Spacer(minLength: 8)
                if !card.isChinese { LevelBadge(level: selectedLevel) }
            }
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(card.isChinese ? Brand.green : .secondary)
            }
            // `pronunciation` often mirrors `ipa` (same transcription, maybe wrapped in slashes) —
            // only show it when it actually differs, otherwise the header reads twice.
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
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            PronounceButton(text: card.word, language: card.cardLanguage, size: 40, font: .title3)
            askAIButton
        }
    }

    private var askAIButton: some View {
        Button {
            showAgent = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Hỏi AI")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.green)
    }

    private var hasMeta: Bool {
        !(card.partOfSpeech ?? "").isEmpty || !(card.topic ?? "").isEmpty
    }

    // MARK: - Level

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cấp độ").font(.headline)
                Spacer()
                if isUpdatingLevel { ProgressView() }
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
            }
        }
    }

    // MARK: - Lists

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
            section("Mẹo ghi nhớ", text: text, icon: "lightbulb")
        }
        if let text = card.toeicTrap, !text.isEmpty {
            section("Bẫy TOEIC", text: text, icon: "exclamationmark.triangle")
        }
        tagsSection
    }

    @ViewBuilder private var chineseContent: some View {
        if horizontalSizeClass == .regular {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    HanziWritingView(word: card.word)
                        .frame(minWidth: 360, maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 16) {
                        chineseInfoCard
                        chineseExampleCard
                    }
                    .frame(width: 380)
                }

                VStack(alignment: .leading, spacing: 20) {
                    HanziWritingView(word: card.word)
                    chineseInfoCard
                    chineseExampleCard
                }
            }
        } else {
            HanziWritingView(word: card.word)
            chineseInfoCard
            chineseExampleCard
        }
    }

    private var chineseInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let meaning = card.meaningVi, !meaning.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundStyle(Brand.green)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nghĩa").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(meaning).font(.title3.weight(.semibold))
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                if let pos = card.partOfSpeech, !pos.isEmpty { metaChip(pos) }
                if let topic = card.topic, !topic.isEmpty { Badge(text: topic) }
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder private var chineseExampleCard: some View {
        if let raw = card.examples?.first(where: { !$0.isEmpty }) {
            let example = ChineseExample(raw)
            VStack(alignment: .leading, spacing: 7) {
                Label("Ví dụ", systemImage: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(example.hanzi).font(.title3.weight(.semibold))
                if let pinyin = example.pinyin {
                    Text(pinyin).foregroundStyle(Brand.green)
                }
                if let meaning = example.meaningVi {
                    Text(meaning).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder private var examplesSection: some View {
        let examples = (card.examples ?? []).filter { !$0.isEmpty }
        if !examples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Ví dụ", icon: "text.quote")
                ForEach(examples, id: \.self) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(example)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var useCasesSection: some View {
        let useCases = (card.useCases ?? []).filter { !$0.isEmpty }
        if !useCases.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Cách dùng", icon: "list.bullet")
                ForEach(useCases, id: \.self) { useCase in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(useCase)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var tagsSection: some View {
        let tags = (card.tags ?? []).filter { !$0.isEmpty }
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Thẻ", icon: "tag")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { metaChip($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                if isDeleting { ProgressView() }
                Text("Xóa thẻ")
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

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(title)
        }
        .font(.headline)
    }

    private func section(_ title: String, text: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(title, icon: icon)
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Actions

    private func updateLevel(to newValue: CardLevel) {
        guard CardLevel(card.level) != newValue else { return }
        isUpdatingLevel = true
        errorMessage = nil
        Task {
            do {
                card = try await cards.setLevel(slug: card.slug, level: newValue.rawValue)
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                selectedLevel = CardLevel(card.level) ?? selectedLevel
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
                onDeleted()
                dismiss()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                isDeleting = false
            }
        }
    }
}

/// Normalises an IPA/pronunciation string for duplicate detection: strips slashes,
/// brackets and whitespace, lowercased — so "/rɪˈteɪn/" == "rɪˈteɪn".
fileprivate func normalizedTranscription(_ raw: String) -> String {
    raw.lowercased().filter { !"/[]() \t\n".contains($0) }
}
