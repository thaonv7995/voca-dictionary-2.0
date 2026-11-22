import AppIntents
import SwiftUI
import WidgetKit

private let brandGreen = Color(red: 0.086, green: 0.639, blue: 0.463)

struct VocaEntry: TimelineEntry {
    let date: Date
    let card: WidgetCard?
    let cardIndex: Int
    let hanziStrokes: [String: [String]]
}

struct VocaProvider: TimelineProvider {
    private let sample = WidgetCard(word: "你好", ipa: nil, pronunciation: "nǐ hǎo",
                                    language: "zh-CN", meaningVi: "xin chào",
                                    partOfSpeech: "phrase")

    func placeholder(in context: Context) -> VocaEntry {
        VocaEntry(date: Date(), card: sample, cardIndex: 0, hanziStrokes: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (VocaEntry) -> Void) {
        let cards = WidgetSharedStore.load()
        let selected = selectedCard(from: cards, at: Date())
        let card = selected?.card ?? sample
        Task {
            let strokes = await WidgetHanziStrokeRepository.shared.cachedStrokes(for: card)
            completion(VocaEntry(date: Date(), card: card,
                                 cardIndex: selected?.index ?? 0, hanziStrokes: strokes))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocaEntry>) -> Void) {
        let cards = WidgetSharedStore.load()
        let now = Date()
        Task {
            // Prefetch missing strokes for the immediate upcoming Chinese cards *before* calling
            // completion so WidgetKit does not terminate the extension mid-download.
            var immediateChinese: [WidgetCard] = []
            for slot in 0..<6 {
                let date = now.addingTimeInterval(Double(slot) * WidgetSharedStore.rotationInterval)
                if let card = selectedCard(from: cards, at: date)?.card,
                   card.language == "zh-CN",
                   !immediateChinese.contains(card) {
                    immediateChinese.append(card)
                }
            }
            if !immediateChinese.isEmpty {
                await WidgetHanziStrokeRepository.shared.prefetchBestEffort(
                    cards: Array(immediateChinese.prefix(4)),
                    timeoutSeconds: 2.5
                )
            }

            var entries: [VocaEntry] = []
            for slot in 0..<24 {
                let seconds = Double(slot) * WidgetSharedStore.rotationInterval
                let date = now.addingTimeInterval(seconds)
                let selected = selectedCard(from: cards, at: date)
                let strokes = await WidgetHanziStrokeRepository.shared
                    .cachedStrokes(for: selected?.card)
                entries.append(VocaEntry(date: date, card: selected?.card,
                                         cardIndex: selected?.index ?? 0,
                                         hanziStrokes: strokes))
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func selectedCard(from cards: [WidgetCard], at date: Date) -> (card: WidgetCard, index: Int)? {
        guard !cards.isEmpty else { return nil }
        guard let index = WidgetSharedStore.scheduledIndex(cardCount: cards.count, at: date)
        else { return nil }
        return (cards[index], index)
    }
}

struct RandomWidgetCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Từ ngẫu nhiên"
    static let description = IntentDescription("Chọn một từ khác ngẫu nhiên trong widget Voca.")
    static let openAppWhenRun = false

    @Parameter(title: "Vị trí hiện tại") var currentIndex: Int

    init() { currentIndex = 0 }
    init(currentIndex: Int) { self.currentIndex = currentIndex }

    func perform() async throws -> some IntentResult {
        let cards = WidgetSharedStore.load()
        _ = WidgetSharedStore.selectRandom(cardCount: cards.count, currentIndex: currentIndex)
        WidgetCenter.shared.reloadTimelines(ofKind: "VocaWidget")
        return .result()
    }
}

private func widgetCardURL(_ card: WidgetCard) -> URL? {
    guard let slug = card.slug, !slug.isEmpty,
          let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    else { return URL(string: "voca://today") }
    return URL(string: "voca://card/\(encoded)")
}

private struct WidgetHanziData: Decodable {
    let strokes: [String]
}

private actor WidgetHanziStrokeRepository {
    static let shared = WidgetHanziStrokeRepository()

    func cachedStrokes(for card: WidgetCard?) -> [String: [String]] {
        guard let card, card.language == "zh-CN" else { return [:] }
        var result: [String: [String]] = [:]
        for character in hanziCharacters(in: card.word).prefix(2) {
            if let data = cached(character) { result[character] = data.strokes }
        }
        return result
    }

    func prefetchBestEffort(cards: [WidgetCard], timeoutSeconds: TimeInterval) async {
        var missing: [String] = []
        var seen = Set<String>()
        for card in cards where card.language == "zh-CN" {
            for character in hanziCharacters(in: card.word).prefix(2)
                where !seen.contains(character) && cached(character) == nil {
                seen.insert(character)
                missing.append(character)
            }
        }
        guard !missing.isEmpty else { return }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        await withTaskGroup(of: Void.self) { group in
            for character in missing.prefix(6) {
                group.addTask {
                    _ = await self.download(character, session: session)
                }
            }
        }
    }

    private func cached(_ character: String) -> WidgetHanziData? {
        let cacheURL = cachedFile(for: character)
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(WidgetHanziData.self, from: data) {
            return decoded
        }
        return nil
    }

    private func download(_ character: String, session: URLSession = .shared) async -> WidgetHanziData? {
        let cacheURL = cachedFile(for: character)
        guard let escaped = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/\(escaped).json"),
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(WidgetHanziData.self, from: data)
        else { return nil }
        if let cacheURL { try? data.write(to: cacheURL, options: .atomic) }
        return decoded
    }

    private func cachedFile(for character: String) -> URL? {
        guard let root = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedStore.appGroup)?
            .appendingPathComponent("HanziWriterData", isDirectory: true)
        else { return nil }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = character.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
        return root.appendingPathComponent(name).appendingPathExtension("json")
    }
}

private func hanziCharacters(in word: String) -> [String] {
    word.map(String.init).filter { value in
        value.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
                || (0x20000...0x323AF).contains(scalar.value)
        }
    }
}

private enum HanziSVGPathParser {
    static func path(from source: String, size: CGFloat) -> Path? {
        let tokens = source.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let margin = size * 0.06
        let scale = (size - margin * 2) / 1024
        var index = 0
        var path = Path()

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: margin + CGFloat(x) * scale,
                    y: margin + CGFloat(900 - y) * scale)
        }

        func number(_ offset: Int) -> Double? {
            guard index + offset < tokens.count else { return nil }
            return Double(tokens[index + offset])
        }

        while index < tokens.count {
            switch tokens[index] {
            case "M":
                guard let x = number(1), let y = number(2) else { return nil }
                path.move(to: point(x, y)); index += 3
            case "L":
                guard let x = number(1), let y = number(2) else { return nil }
                path.addLine(to: point(x, y)); index += 3
            case "Q":
                guard let cx = number(1), let cy = number(2),
                      let x = number(3), let y = number(4) else { return nil }
                path.addQuadCurve(to: point(x, y), control: point(cx, cy)); index += 5
            case "C":
                guard let c1x = number(1), let c1y = number(2),
                      let c2x = number(3), let c2y = number(4),
                      let x = number(5), let y = number(6) else { return nil }
                path.addCurve(to: point(x, y), control1: point(c1x, c1y),
                              control2: point(c2x, c2y)); index += 7
            case "Z":
                path.closeSubpath(); index += 1
            default:
                return nil
            }
        }
        return path
    }
}

struct VocaWidgetEntryView: View {
    var entry: VocaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let card = entry.card {
                content(card)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .widgetURL(cardURL(card))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Mở Voca để đồng bộ từ vựng").font(.caption)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "voca://today"))
            }
        }
        #if os(macOS)
        .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        #else
        .containerBackground(for: .widget) { Color(.systemBackground) }
        #endif
    }

    @ViewBuilder private func content(_ card: WidgetCard) -> some View {
        if family == .systemLarge {
            largeContent(card)
        } else if family == .systemMedium {
            mediumContent(card)
        } else {
            smallContent(card)
        }
    }

    private func largeContent(_ card: WidgetCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                wordHeader(card, compact: false)
                Spacer(minLength: 8)
                if let pos = card.partOfSpeech, !pos.isEmpty {
                    posBadge(pos)
                }
            }

            if card.language == "zh-CN" {
                HanziWidgetGuide(word: card.word, size: 116, strokes: entry.hanziStrokes)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                largeMeaning(card)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 12) {
                if card.language == "zh-CN" {
                    largeMeaning(card)
                }
                Spacer(minLength: 8)
                randomButton
            }
        }
        .padding(.vertical, 4)
    }

    private func mediumContent(_ card: WidgetCard) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                wordHeader(card, compact: false)
                if let pos = card.partOfSpeech, !pos.isEmpty { posBadge(pos) }
                Spacer(minLength: 6)
                meaning(card, compact: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .trailing, spacing: 4) {
                if card.language == "zh-CN" {
                    HanziWidgetGuide(word: card.word, size: 76, strokes: entry.hanziStrokes)
                        .frame(width: 156, alignment: .trailing)
                }
                Spacer(minLength: 0)
                randomButton
            }
            .frame(maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(.vertical, 2)
    }

    private func smallContent(_ card: WidgetCard) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            wordHeader(card, compact: true)
            if card.language == "zh-CN" {
                HanziWidgetGuide(word: card.word, size: 40, strokes: entry.hanziStrokes)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                meaning(card, compact: true)
                randomButton
            }
        }
        .padding(.vertical, 2)
    }

    private func wordHeader(_ card: WidgetCard, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(card.word)
                .font(card.language == "zh-CN"
                      ? .system(size: compact ? 27 : 34, weight: .bold)
                      : .system(size: compact ? 22 : 30, weight: .bold))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(card.language == "zh-CN" ? brandGreen : .secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder private func meaning(_ card: WidgetCard, compact: Bool) -> some View {
        if let vi = card.meaningVi, !vi.isEmpty {
            Text(vi)
                .font(compact ? .caption : .subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(compact ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func largeMeaning(_ card: WidgetCard) -> some View {
        if let vi = card.meaningVi, !vi.isEmpty {
            Text(vi)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func posBadge(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(brandGreen.opacity(0.15), in: Capsule())
            .foregroundStyle(brandGreen)
    }

    private var randomButton: some View {
        actionButton("shuffle", label: "Từ ngẫu nhiên",
                     intent: RandomWidgetCardIntent(currentIndex: entry.cardIndex))
            .foregroundStyle(brandGreen)
    }

    private func actionButton<I: AppIntent>(_ icon: String, label: String, intent: I) -> some View {
        Button(intent: intent) {
            actionIcon(icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func actionIcon(_ icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(brandGreen.opacity(0.14))
                .frame(width: 38, height: 38)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private func cardURL(_ card: WidgetCard) -> URL? {
        widgetCardURL(card)
    }

}

private struct HanziWidgetGuide: View {
    @Environment(\.colorScheme) private var colorScheme
    let word: String
    let size: CGFloat
    let strokes: [String: [String]]

    private var characters: [String] {
        Array(hanziCharacters(in: word).prefix(2))
    }

    private var hasCompleteStrokeData: Bool {
        !characters.isEmpty && characters.allSatisfy { !(strokes[$0] ?? []).isEmpty }
    }

    var body: some View {
        let isDark = colorScheme == .dark
        let tileFill = isDark ? Color(red: 0.14, green: 0.16, blue: 0.19) : Color.white
        let borderColor = isDark ? Color.white.opacity(0.16) : Color(red: 0.82, green: 0.85, blue: 0.89)
        let inkColor = isDark ? Color(red: 0.94, green: 0.96, blue: 0.98) : Color(red: 0.06, green: 0.09, blue: 0.15)
        let guideColor = isDark
            ? Color.white.opacity(0.22)
            : Color(red: 0.55, green: 0.66, blue: 0.79).opacity(0.5)

        HStack(spacing: 4) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.12).fill(tileFill)
                    Canvas { context, canvasSize in
                        var horizontal = Path()
                        horizontal.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
                        horizontal.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
                        var vertical = Path()
                        vertical.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
                        vertical.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
                        let style = StrokeStyle(lineWidth: 0.85, dash: [3, 3])
                        context.stroke(horizontal, with: .color(guideColor), style: style)
                        context.stroke(vertical, with: .color(guideColor), style: style)
                    }
                    if hasCompleteStrokeData, let paths = strokes[character] {
                        Canvas { context, canvasSize in
                            for svgPath in paths {
                                if let path = HanziSVGPathParser.path(
                                    from: svgPath, size: min(canvasSize.width, canvasSize.height)) {
                                    context.fill(path, with: .color(inkColor))
                                }
                            }
                        }
                    } else {
                        Text(character)
                            .font(.system(size: size * 0.68, weight: .bold, design: .serif))
                            .foregroundStyle(inkColor)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
                .overlay(RoundedRectangle(cornerRadius: size * 0.12)
                    .stroke(borderColor, lineWidth: 1.5))
                .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 2, y: 1)
            }
        }
    }
}

struct VocaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VocaWidget", provider: VocaProvider()) { entry in
            VocaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Từ vựng")
        .description("Ôn từ, đổi từ và mở nhanh màn chi tiết.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct VocaWidgetBundle: WidgetBundle {
    var body: some Widget { VocaWidget() }
}
