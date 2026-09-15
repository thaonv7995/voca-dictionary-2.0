import AppIntents
import SwiftUI
import WidgetKit

private let brandGreen = Color(red: 0.086, green: 0.639, blue: 0.463)

struct VocaEntry: TimelineEntry {
    let date: Date
    let card: WidgetCard?
    let cardIndex: Int
}

struct VocaProvider: TimelineProvider {
    private let sample = WidgetCard(word: "你好", ipa: nil, pronunciation: "nǐ hǎo",
                                    language: "zh-CN", meaningVi: "xin chào",
                                    partOfSpeech: "phrase")

    func placeholder(in context: Context) -> VocaEntry {
        VocaEntry(date: Date(), card: sample, cardIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (VocaEntry) -> Void) {
        let cards = WidgetSharedStore.load()
        let selected = selectedCard(from: cards, at: Date())
        completion(VocaEntry(date: Date(), card: selected?.card ?? sample,
                            cardIndex: selected?.index ?? 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocaEntry>) -> Void) {
        let cards = WidgetSharedStore.load()
        let now = Date()
        let calendar = Calendar.current
        let entries = (0..<12).map { hour in
            let date = calendar.date(byAdding: .hour, value: hour, to: now) ?? now
            let selected = selectedCard(from: cards, at: date)
            return VocaEntry(date: date, card: selected?.card, cardIndex: selected?.index ?? 0)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
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
                if card.language == "zh-CN" { HanziWidgetGuide(word: card.word, size: 72) }
            }
            .padding(.bottom, 28)
            .overlay(alignment: .bottom) { actionRow(compact: false) }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    wordInfo(card)
                    Spacer(minLength: 2)
                    if card.language == "zh-CN" { HanziWidgetGuide(word: card.word, size: 38) }
                }
                Spacer(minLength: 0)
                actionRow(compact: true)
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

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 12 : 16) {
            if compact {
                Button(intent: NextWidgetCardIntent(currentIndex: entry.cardIndex)) {
                    Image(systemName: "arrow.right")
                }
                .accessibilityLabel("Từ tiếp theo")
                Button(intent: RandomWidgetCardIntent(currentIndex: entry.cardIndex)) {
                    Image(systemName: "shuffle")
                }
                .accessibilityLabel("Từ ngẫu nhiên")
            } else {
                Button(intent: NextWidgetCardIntent(currentIndex: entry.cardIndex)) {
                    Label("Tiếp", systemImage: "arrow.right")
                }
                Button(intent: RandomWidgetCardIntent(currentIndex: entry.cardIndex)) {
                    Label("Ngẫu nhiên", systemImage: "shuffle")
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
            Text("Voca").font(.caption2.weight(.semibold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(brandGreen)
    }

    private func cardURL(_ card: WidgetCard) -> URL? {
        guard let slug = card.slug, !slug.isEmpty,
              let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return URL(string: "voca://today") }
        return URL(string: "voca://card/\(encoded)")
    }
}

private struct HanziWidgetGuide: View {
    let word: String
    let size: CGFloat

    private var characters: [String] {
        word.map(String.init).filter { value in
            value.unicodeScalars.contains { scalar in
                (0x3400...0x4DBF).contains(scalar.value)
                    || (0x4E00...0x9FFF).contains(scalar.value)
                    || (0xF900...0xFAFF).contains(scalar.value)
                    || (0x20000...0x323AF).contains(scalar.value)
            }
        }
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
                        let style = StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                        context.stroke(horizontal, with: .color(.gray.opacity(0.35)), style: style)
                        context.stroke(vertical, with: .color(.gray.opacity(0.35)), style: style)
                    }
                    Text(character)
                        .font(.system(size: size * 0.68, weight: .semibold))
                        .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.15))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
                .overlay(RoundedRectangle(cornerRadius: size * 0.12)
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1))
            }
        }
    }
}

struct VocaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VocaWidget", provider: VocaProvider()) { entry in
            VocaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Từ vựng Voca")
        .description("Ôn từ, đổi từ và mở nhanh màn chi tiết.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VocaWidgetBundle: WidgetBundle {
    var body: some Widget { VocaWidget() }
}
