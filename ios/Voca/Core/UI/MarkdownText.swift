import SwiftUI

/// Lightweight block-level Markdown renderer for AI replies.
///
/// SwiftUI's built-in Markdown (`AttributedString(markdown:)`) only handles INLINE styles —
/// headings, lists, tables and code fences come out as raw `##`/`|---|` garbage, which is what
/// assistant replies are full of. This view splits the text into blocks (heading / bullet list /
/// table / code fence / paragraph) and renders each, applying inline markdown inside.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(Self.blocks(from: text).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    // MARK: - Blocks

    enum Block {
        case heading(Int, String)
        case bullets([String])
        case table(header: [String], rows: [[String]])
        case code(String)
        case paragraph(String)
    }

    static func blocks(from text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var tableRows: [[String]] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        func flushBullets() {
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
        }
        func flushTable() {
            guard !tableRows.isEmpty else { return }
            let header = tableRows.first ?? []
            let rows = Array(tableRows.dropFirst())
            blocks.append(.table(header: header, rows: rows))
            tableRows = []
        }
        func flushAll() { flushParagraph(); flushBullets(); flushTable() }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    flushAll()
                    inCode = true
                }
                continue
            }
            if inCode { codeLines.append(rawLine); continue }

            if line.isEmpty { flushAll(); continue }

            // Table row: |cell|cell| — skip pure separator rows (|---|:---:|).
            if line.hasPrefix("|") {
                flushParagraph(); flushBullets()
                let inner = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                let isSeparator = inner.allSatisfy { "-: |".contains($0) }
                if !isSeparator {
                    let cells = inner.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    tableRows.append(cells)
                }
                continue
            } else {
                flushTable()
            }

            // Heading: #, ##, ###…
            if line.hasPrefix("#") {
                flushParagraph(); flushBullets()
                let level = line.prefix(while: { $0 == "#" }).count
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(min(level, 3), title))
                continue
            }

            // Bullet / numbered list item.
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph()
                bullets.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }
            if let match = line.range(of: #"^\d{1,2}\.\s+"#, options: .regularExpression) {
                flushParagraph()
                bullets.append(String(line[match.upperBound...]))
                continue
            }

            flushBullets()
            paragraph.append(rawLine)
        }
        if inCode, !codeLines.isEmpty { blocks.append(.code(codeLines.joined(separator: "\n"))) }
        flushAll()
        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder private func render(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let title):
            inline(title)
                .font(level == 1 ? .title3.bold() : level == 2 ? .headline : .subheadline.bold())
                .padding(.top, 2)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(.secondary)
                        inline(item)
                    }
                }
            }

        case .table(let header, let rows):
            VStack(alignment: .leading, spacing: 6) {
                if !header.isEmpty {
                    inline(header.joined(separator: " · "))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 1) {
                        if let first = row.first, !first.isEmpty {
                            inline(first).font(.subheadline.weight(.semibold))
                        }
                        if row.count > 1 {
                            inline(row.dropFirst().joined(separator: " — "))
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
                }
            }
            .padding(8)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.footnote.monospaced())
                    .padding(8)
            }
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .paragraph(let text):
            inline(text)
        }
    }

    /// Inline markdown (**bold**, *italic*, `code`) with whitespace preserved; falls back to plain text.
    private func inline(_ string: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return Text(attributed)
        }
        return Text(string)
    }
}
