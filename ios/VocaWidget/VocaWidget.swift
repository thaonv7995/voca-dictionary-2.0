import WidgetKit
import SwiftUI

private let brandGreen = Color(red: 0.086, green: 0.639, blue: 0.463)

struct VocaEntry: TimelineEntry {
    let date: Date
    let card: WidgetCard?
}

struct VocaProvider: TimelineProvider {
    private let sample = WidgetCard(word: "retain", ipa: "/rɪˈteɪn/",
                                    meaningVi: "giữ lại, duy trì", partOfSpeech: "verb")

    func placeholder(in context: Context) -> VocaEntry {
        VocaEntry(date: Date(), card: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (VocaEntry) -> Void) {
        let cards = WidgetSharedStore.load()
        completion(VocaEntry(date: Date(), card: cards.first ?? sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocaEntry>) -> Void) {
        let cards = WidgetSharedStore.load()
        let now = Date()
        let calendar = Calendar.current
        var entries: [VocaEntry] = []
        // Rotate to a different word each hour for the next 12 hours.
        for hour in 0..<12 {
            let date = calendar.date(byAdding: .hour, value: hour, to: now) ?? now
            let card = cards.isEmpty ? nil : cards[index(for: date, count: cards.count)]
            entries.append(VocaEntry(date: date, card: card))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func index(for date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let cal = Calendar.current
        let slot = (cal.ordinality(of: .hour, in: .era, for: date)) ?? cal.component(.hour, from: date)
        return ((slot % count) + count) % count
    }
}

struct VocaWidgetEntryView: View {
    var entry: VocaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let card = entry.card {
                content(card)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Mở Voca để đồng bộ từ vựng").font(.caption)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(URL(string: "voca://today"))
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    @ViewBuilder private func content(_ card: WidgetCard) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(family == .systemSmall ? .title3.bold() : .title2.bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let pos = card.partOfSpeech, !pos.isEmpty {
                    Text(pos)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(brandGreen.opacity(0.15), in: Capsule())
                        .foregroundStyle(brandGreen)
                }
            }
            if let ipa = card.ipa, !ipa.isEmpty {
                Text(ipa).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if let vi = card.meaningVi, !vi.isEmpty {
                Text(vi)
                    .font(family == .systemSmall ? .caption : .subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 3 : 4)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.caption2)
                Text("Voca").font(.caption2.weight(.semibold))
            }
            .foregroundStyle(brandGreen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct VocaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VocaWidget", provider: VocaProvider()) { entry in
            VocaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Từ vựng Voca")
        .description("Ôn một từ mỗi giờ ngay trên màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VocaWidgetBundle: WidgetBundle {
    var body: some Widget {
        VocaWidget()
    }
}
