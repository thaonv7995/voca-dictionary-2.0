import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

struct MacImportCandidate: Identifiable, Equatable, Sendable {
    enum Status: String, Equatable, Sendable {
        case new
        case duplicate
        case invalid
    }

    let id: String
    var word: String
    var language: MacVocabularyItem.Language
    var status: Status
    var isSelected: Bool
}

enum MacImportParser {
    static func extractCandidates(
        from rawText: String,
        existingItems: [MacVocabularyItem]
    ) -> [MacImportCandidate] {
        let existingNormalized = Set(
            existingItems.map {
                $0.term
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
        )

        let rawLines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Check if JSON array/object
        if let jsonCandidates = parseJSONIfApplicable(
            rawText: rawText,
            existingNormalized: existingNormalized
        ) {
            return jsonCandidates
        }

        var results: [MacImportCandidate] = []
        var seen: Set<String> = []

        for line in rawLines {
            // Skip common CSV header line
            if line.lowercased().hasPrefix("word,")
                || line.lowercased() == "word"
                || line.lowercased().hasPrefix("term,") {
                continue
            }

            let columns = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map {
                    $0.trimmingCharacters(
                        in: CharacterSet.whitespacesAndNewlines
                            .union(CharacterSet(charactersIn: "\"'"))
                    )
                }

            let candidateWord = columns.first ?? line
            let normalized = candidateWord.lowercased()

            guard !normalized.isEmpty,
                  seen.insert(normalized).inserted
            else {
                continue
            }

            let isDuplicate = existingNormalized.contains(normalized)
            let isValid = candidateWord.count <= 64
                && candidateWord.rangeOfCharacter(from: .letters) != nil

            let language: MacVocabularyItem.Language = containsHanCharacters(candidateWord)
                ? .chinese
                : .english

            let status: MacImportCandidate.Status
            if !isValid {
                status = .invalid
            } else if isDuplicate {
                status = .duplicate
            } else {
                status = .new
            }

            results.append(
                MacImportCandidate(
                    id: normalized,
                    word: candidateWord,
                    language: language,
                    status: status,
                    isSelected: status == .new
                )
            )
        }

        return results
    }

    static func exportCSV(items: [MacVocabularyItem]) -> String {
        var lines = ["word,pronunciation,meaning,language,level,tags,favorite"]
        for item in items {
            let fields = [
                escapeCSV(item.term),
                escapeCSV(item.pronunciation ?? ""),
                escapeCSV(item.meaning),
                escapeCSV(item.language.rawValue),
                escapeCSV(item.level ?? ""),
                escapeCSV(item.tags.joined(separator: ";")),
                item.isFavorite ? "true" : "false"
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func exportJSON(items: [MacVocabularyItem]) -> String {
        struct ExportRecord: Encodable {
            let id: String
            let word: String
            let pronunciation: String?
            let meaning: String
            let language: String
            let level: String?
            let tags: [String]
            let isFavorite: Bool
            let personalNote: String
        }

        let records = items.map {
            ExportRecord(
                id: $0.id,
                word: $0.term,
                pronunciation: $0.pronunciation,
                meaning: $0.meaning,
                language: $0.language.rawValue,
                level: $0.level,
                tags: $0.tags,
                isFavorite: $0.isFavorite,
                personalNote: $0.personalNote
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private static func parseJSONIfApplicable(
        rawText: String,
        existingNormalized: Set<String>
    ) -> [MacImportCandidate]? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[") || trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }

        var words: [String] = []
        if let stringArray = json as? [String] {
            words = stringArray
        } else if let objectArray = json as? [[String: Any]] {
            words = objectArray.compactMap {
                ($0["word"] as? String) ?? ($0["term"] as? String)
            }
        } else if let root = json as? [String: Any],
                  let cards = root["cards"] as? [[String: Any]] {
            words = cards.compactMap {
                ($0["word"] as? String) ?? ($0["term"] as? String)
            }
        }

        guard !words.isEmpty else { return nil }

        var seen: Set<String> = []
        return words.compactMap { rawWord in
            let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = word.lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            let isDuplicate = existingNormalized.contains(normalized)
            let language: MacVocabularyItem.Language = containsHanCharacters(word)
                ? .chinese
                : .english
            return MacImportCandidate(
                id: normalized,
                word: word,
                language: language,
                status: isDuplicate ? .duplicate : .new,
                isSelected: !isDuplicate
            )
        }
    }

    private static func containsHanCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    static func extractTextFromFile(at url: URL) async -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return extractTextFromPDF(at: url)
        }

        if ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp"].contains(ext) {
            return await recognizeTextFromImage(at: url)
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return ""
    }

    static func extractTextFromPDF(at url: URL) -> String {
        guard let document = PDFDocument(url: url) else {
            return ""
        }

        var pagesText: [String] = []
        let maxPages = min(document.pageCount, 30)
        for index in 0..<maxPages {
            if let page = document.page(at: index),
               let content = page.string,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pagesText.append(content)
            }
        }

        return tokenizeDocumentTextIntoCandidateLines(
            pagesText.joined(separator: "\n")
        )
    }

    static func recognizeTextFromImage(at url: URL) async -> String {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return ""
        }
        return await recognizeText(from: cgImage)
    }

    static func recognizeText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }
                let combined = tokenizeDocumentTextIntoCandidateLines(
                    lines.joined(separator: "\n")
                )
                continuation.resume(returning: combined)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "vi-VN"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    static func tokenizeDocumentTextIntoCandidateLines(_ rawText: String) -> String {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // If lines are already single words or CSV, keep them directly
        if lines.allSatisfy({ $0.count <= 36 && !$0.contains(" ") || $0.contains(",") }) {
            return lines.joined(separator: "\n")
        }

        // Otherwise extract meaningful English words (>= 4 letters) or Chinese tokens
        let stopWords: Set<String> = [
            "that", "this", "with", "from", "your", "have", "more", "will",
            "when", "what", "which", "their", "there", "been", "were", "they",
            "into", "some", "than", "then", "also", "only", "over", "such"
        ]

        var tokens: [String] = []
        var seen: Set<String> = []

        let separators = CharacterSet.alphanumerics.inverted
        for rawToken in rawText.components(separatedBy: separators) {
            let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            if containsHanCharacters(token) {
                if token.count >= 1, token.count <= 8, seen.insert(token).inserted {
                    tokens.append(token)
                }
            } else {
                let lower = token.lowercased()
                if token.count >= 4,
                   token.count <= 28,
                   !stopWords.contains(lower),
                   token.allSatisfy(\.isLetter),
                   seen.insert(lower).inserted {
                    tokens.append(lower)
                }
            }
        }

        return tokens.isEmpty ? rawText : tokens.joined(separator: "\n")
    }
}

struct MacImportExportSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case importWords = "Import"
        case exportWords = "Export"

        var id: String { rawValue }
    }

    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(\.dismiss) private var dismiss

    @ViewState private var mode: Mode
    @ViewState private var rawInput = ""
    @ViewState private var candidates: [MacImportCandidate] = []
    @ViewState private var isImporting = false
    @ViewState private var isExtractingFile = false
    @ViewState private var isFileImporterPresented = false
    @ViewState private var importedCount = 0
    @ViewState private var exportFormat: String = "CSV"
    @ViewState private var statusMessage: String?
    @ViewState private var lastExportedFileURL: URL?

    init(
        initialMode: Mode = .importWords,
        initialText: String? = nil
    ) {
        _mode = State(initialValue: initialMode)
        _rawInput = State(initialValue: initialText ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VocaIconBadge(
                    systemImage: mode == .importWords ? "square.and.arrow.down.fill" : "square.and.arrow.up.fill",
                    tint: VocaDesign.brandGreen,
                    size: 38,
                    iconSize: 17
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .importWords ? "Import & Capture Vocabulary" : "Export Vocabulary")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Supports plain text, CSV, JSON, PDF documents, and Vision Image OCR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Mode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 148)
                }

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(VocaSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            }

            Divider().opacity(0.6)

            if mode == .importWords {
                importSection
            } else {
                exportSection
            }
        }
        .padding(24)
        .frame(width: 680, height: 520)
        .onAppear {
            if !rawInput.isEmpty {
                candidates = MacImportParser.extractCandidates(
                    from: rawInput,
                    existingItems: vocabulary.items
                )
            }
        }
        .onChange(of: rawInput) { _, newValue in
            candidates = MacImportParser.extractCandidates(
                from: newValue,
                existingItems: vocabulary.items
            )
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText, .commaSeparatedText, .json, .pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                loadFile(from: url)
            }
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(
                    "Paste words, CSV/JSON, or choose a PDF / image for Vision OCR."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                if isExtractingFile {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Choose File / OCR…", systemImage: "doc.viewfinder")
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button {
                    if let string = NSPasteboard.general.string(forType: .string) {
                        rawInput = string
                    }
                } label: {
                    Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(VocaSecondaryButtonStyle())
            }

            HSplitView {
                TextEditor(text: $rawInput)
                    .font(.body.monospaced())
                    .padding(8)
                    .frame(minWidth: 260, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Candidates (\(selectedCandidates.count) selected)")
                            .font(.headline)

                        Spacer()
                    }

                    if candidates.isEmpty {
                        ContentUnavailableView(
                            "No Candidates",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Enter or paste text on the left to preview candidates.")
                        )
                    } else {
                        List($candidates) { $candidate in
                            HStack {
                                Toggle("", isOn: $candidate.isSelected)
                                    .labelsHidden()
                                    .disabled(candidate.status != .new)

                                Text(candidate.word)
                                    .font(.body.weight(.medium))

                                Spacer()

                                Text(candidate.language.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                statusBadge(candidate.status)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 280, maxHeight: .infinity)
            }

            HStack {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    runImport()
                } label: {
                    HStack(spacing: 6) {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(
                            isImporting
                                ? "Importing (\(importedCount)/\(selectedCandidates.count))…"
                                : "Import \(selectedCandidates.count) Words with AI"
                        )
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .disabled(isImporting || selectedCandidates.isEmpty)
            }
        }
    }

    private var exportSection: some View {
        let exportedText = exportFormat == "CSV"
            ? MacImportParser.exportCSV(items: vocabulary.items)
            : MacImportParser.exportJSON(items: vocabulary.items)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("Export \(vocabulary.items.count) vocabulary items.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    Text("Format")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Format", selection: $exportFormat) {
                        Text("CSV").tag("CSV")
                        Text("JSON").tag("JSON")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 136)
                }
            }

            ScrollView {
                Text(exportedText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            HStack(spacing: 10) {
                if let statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(VocaDesign.brandGreen)
                        Text(statusMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VocaDesign.brandGreen)
                            .lineLimit(1)

                        if let lastExportedFileURL {
                            Button("Mở trong Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([lastExportedFileURL])
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VocaDesign.accentSky)
                        }
                    }
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportedText, forType: .string)
                    lastExportedFileURL = nil
                    statusMessage = "Đã sao chép \(vocabulary.items.count) từ vựng vào Clipboard."
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button {
                    downloadExportedFile(content: exportedText)
                } label: {
                    Label(
                        "Tải về file .\(exportFormat.lowercased())",
                        systemImage: "arrow.down.doc.fill"
                    )
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .keyboardShortcut("s", modifiers: .command)
                .help("Lưu file .\(exportFormat.lowercased()) về máy (⌘S)")
            }
        }
    }

    private static let exportFilenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func downloadExportedFile(content: String) {
        let ext = exportFormat.lowercased()
        let dateStamp = Self.exportFilenameDateFormatter.string(from: Date())
        let suggestedFilename = "voca-vocabulary-\(dateStamp).\(ext)"

        let savePanel = NSSavePanel()
        savePanel.title = "Tải về danh sách từ vựng (\(exportFormat))"
        savePanel.prompt = "Tải về"
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowedContentTypes = ext == "csv" ? [.commaSeparatedText] : [.json]
        if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = downloadsDir
        }

        let response = savePanel.runModal()
        guard response == .OK, let targetURL = savePanel.url else { return }

        do {
            let outputString = ext == "csv" ? "\u{FEFF}" + content : content
            try outputString.write(to: targetURL, atomically: true, encoding: .utf8)
            lastExportedFileURL = targetURL
            statusMessage = "Đã tải về \(targetURL.lastPathComponent)"
        } catch {
            lastExportedFileURL = nil
            statusMessage = "Lỗi lưu file: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: MacImportCandidate.Status) -> some View {
        switch status {
        case .new:
            Text("New")
                .font(.caption2)
                .foregroundStyle(.green)
        case .duplicate:
            Text("Saved")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .invalid:
            Text("Invalid")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    private var selectedCandidates: [MacImportCandidate] {
        candidates.filter { $0.isSelected && $0.status == .new }
    }

    private func runImport() {
        let targets = selectedCandidates
        guard !targets.isEmpty, !isImporting else { return }

        isImporting = true
        importedCount = 0
        statusMessage = nil

        Task {
            for candidate in targets {
                _ = try? await vocabulary.create(
                    word: candidate.word,
                    language: candidate.language
                )
                importedCount += 1
            }
            isImporting = false
            statusMessage = "Imported \(importedCount) words."
            candidates = MacImportParser.extractCandidates(
                from: rawInput,
                existingItems: vocabulary.items
            )
        }
    }

    private func loadFile(from url: URL) {
        isExtractingFile = true
        statusMessage = "Extracting text from \(url.lastPathComponent)…"

        Task {
            let extracted = await MacImportParser.extractTextFromFile(at: url)
            isExtractingFile = false
            if extracted.isEmpty {
                statusMessage = "Could not extract text from \(url.lastPathComponent)."
            } else {
                rawInput = extracted
                statusMessage = "Extracted candidates from \(url.lastPathComponent)."
            }
        }
    }
}
