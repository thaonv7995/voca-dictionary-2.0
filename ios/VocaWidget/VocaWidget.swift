import AppIntents
import SwiftUI
import UIKit
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
            let strokes = await WidgetHanziStrokeRepository.shared.strokes(for: card)
            completion(VocaEntry(date: Date(), card: card,
                                 cardIndex: selected?.index ?? 0, hanziStrokes: strokes))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocaEntry>) -> Void) {
        let cards = WidgetSharedStore.load()
        let now = Date()
        let selected = selectedCard(from: cards, at: now)
        Task {
            let strokes = await WidgetHanziStrokeRepository.shared.strokes(for: selected?.card)
            let entry = VocaEntry(date: now, card: selected?.card,
                                  cardIndex: selected?.index ?? 0, hanziStrokes: strokes)
            let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)
                ?? now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func selectedCard(from cards: [WidgetCard], at date: Date) -> (card: WidgetCard, index: Int)? {
        guard !cards.isEmpty else { return nil }
        if let selected = WidgetSharedStore.selectedIndex(cardCount: cards.count) {
            return (cards[selected], selected)
        }
        let calendar = Calendar.current
        let hour = calendar.ordinality(of: .hour, in: .era, for: date)
            ?? calendar.component(.hour, from: date)
        let index = ((hour % cards.count) + cards.count) % cards.count
        return (cards[index], index)
    }
}

struct NextWidgetCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Từ tiếp theo"
    static let description = IntentDescription("Hiển thị từ tiếp theo trong widget Voca.")
    static let openAppWhenRun = false

    @Parameter(title: "Vị trí hiện tại") var currentIndex: Int

    init() { currentIndex = 0 }
    init(currentIndex: Int) { self.currentIndex = currentIndex }

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.selectNext(cardCount: WidgetSharedStore.load().count,
                                     currentIndex: currentIndex)
        WidgetCenter.shared.reloadTimelines(ofKind: "VocaWidget")
        return .result()
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
        WidgetSharedStore.selectRandom(cardCount: WidgetSharedStore.load().count,
                                       currentIndex: currentIndex)
        WidgetCenter.shared.reloadTimelines(ofKind: "VocaWidget")
        return .result()
    }
}

private struct WidgetHanziData: Decodable {
    let strokes: [String]
}

private actor WidgetHanziStrokeRepository {
    static let shared = WidgetHanziStrokeRepository()

    func strokes(for card: WidgetCard?) async -> [String: [String]] {
        guard let card, card.language == "zh-CN" else { return [:] }
        var result: [String: [String]] = [:]
        for character in hanziCharacters(in: card.word).prefix(2) {
            if let data = await load(character) { result[character] = data.strokes }
        }
        return result
    }

    private func load(_ character: String) async -> WidgetHanziData? {
        let cacheURL = cachedFile(for: character)
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode(WidgetHanziData.self, from: data) {
            return decoded
        }
        guard let escaped = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/\(escaped).json"),
              let (data, response) = try? await URLSession.shared.data(from: url),
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
                content(card).widgetURL(cardURL(card))
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
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder private func content(_ card: WidgetCard) -> some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 14) {
                wordInfo(card)
                Spacer(minLength: 4)
                if card.language == "zh-CN" {
                    HanziWidgetGuide(word: card.word, size: 72, strokes: entry.hanziStrokes)
                }
            }
            .padding(.bottom, 28)
            .overlay(alignment: .bottom) { actionRow }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    wordInfo(card)
                    Spacer(minLength: 2)
                    if card.language == "zh-CN" {
                        HanziWidgetGuide(word: card.word, size: 38, strokes: entry.hanziStrokes)
                    }
                }
                Spacer(minLength: 0)
                actionRow
            }
        }
    }

    private func wordInfo(_ card: WidgetCard) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(card.word)
                    .font(card.language == "zh-CN"
                          ? .system(size: family == .systemSmall ? 27 : 34, weight: .bold)
                          : (family == .systemSmall ? .title3.bold() : .title2.bold()))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                if card.language != "zh-CN", let pos = card.partOfSpeech, !pos.isEmpty {
                    posBadge(pos)
                }
            }
            if let phonetic = card.phonetic {
                Text(phonetic).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            if let vi = card.meaningVi, !vi.isEmpty {
                Text(vi)
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 2 : 3)
            }
            if card.language == "zh-CN", family == .systemMedium,
               let pos = card.partOfSpeech, !pos.isEmpty { posBadge(pos) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func posBadge(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(brandGreen.opacity(0.15), in: Capsule())
            .foregroundStyle(brandGreen)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            if let card = entry.card, let url = pronunciationURL(card) {
                Link(destination: url) {
                    actionIcon("speaker.wave.2.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Phát âm")
            }
            actionButton("arrow.right", label: "Từ tiếp theo",
                         intent: NextWidgetCardIntent(currentIndex: entry.cardIndex))
            actionButton("shuffle", label: "Từ ngẫu nhiên",
                         intent: RandomWidgetCardIntent(currentIndex: entry.cardIndex))
            Spacer(minLength: 0)
        }
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
        Image(systemName: icon)
            .font(.caption.weight(.bold))
            .frame(width: 30, height: 24)
            .background(brandGreen.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
    }

    private func cardURL(_ card: WidgetCard) -> URL? {
        guard let slug = card.slug, !slug.isEmpty,
              let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return URL(string: "voca://today") }
        return URL(string: "voca://card/\(encoded)")
    }

    private func pronunciationURL(_ card: WidgetCard) -> URL? {
        var components = URLComponents()
        components.scheme = "voca"
        components.host = "speak"
        components.path = "/\(card.slug ?? "")"
        components.queryItems = [
            URLQueryItem(name: "text", value: card.word),
            URLQueryItem(name: "language", value: card.language ?? "en")
        ]
        return components.url
    }
}

private struct HanziWidgetGuide: View {
    let word: String
    let size: CGFloat
    let strokes: [String: [String]]

    private var characters: [String] {
        hanziCharacters(in: word)
    }

    private var characterFont: Font {
        let pointSize = size * 0.8
        if let uiFont = UIFont(name: "STKaitiSC-Black", size: pointSize)
            ?? UIFont(name: "STKaitiSC-Bold", size: pointSize)
            ?? UIFont(name: "Kaiti SC", size: pointSize) {
            return Font(uiFont)
        }
        return .system(size: pointSize, weight: .black, design: .serif)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(characters.prefix(2).enumerated()), id: \.offset) { _, character in
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.12).fill(.white)
                    Canvas { context, canvasSize in
                        var horizontal = Path()
                        horizontal.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
                        horizontal.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
                        var vertical = Path()
                        vertical.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
                        vertical.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
                        let style = StrokeStyle(lineWidth: 0.85, dash: [3, 3])
                        let guideColor = Color(red: 0.55, green: 0.66, blue: 0.79).opacity(0.5)
                        context.stroke(horizontal, with: .color(guideColor), style: style)
                        context.stroke(vertical, with: .color(guideColor), style: style)
                    }
                    if let paths = strokes[character], !paths.isEmpty {
                        Canvas { context, canvasSize in
                            for svgPath in paths {
                                if let path = HanziSVGPathParser.path(
                                    from: svgPath, size: min(canvasSize.width, canvasSize.height)) {
                                    context.fill(path, with: .color(
                                        Color(red: 0.06, green: 0.09, blue: 0.15)))
                                }
                            }
                        }
                    } else {
                        Text(character)
                            .font(characterFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(size * 0.05)
                            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.15))
                            .drawingGroup()
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
                .overlay(RoundedRectangle(cornerRadius: size * 0.12)
                    .stroke(Color(red: 0.82, green: 0.85, blue: 0.89), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.07), radius: 2, y: 1)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VocaWidgetBundle: WidgetBundle {
    var body: some Widget { VocaWidget() }
}
