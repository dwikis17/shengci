//
//  shengciWidget.swift
//  shengciWidget
//
//  Created by Dwiki on 28/07/26.
//

import WidgetKit
import SwiftUI

public struct WordOfTheDayEntry: TimelineEntry {
    public let date: Date
    public let word: WordOfTheDay
}

public struct WordOfTheDayProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> WordOfTheDayEntry {
        WordOfTheDayEntry(
            date: Date(),
            word: WordOfTheDay(
                simplified: "学习",
                traditional: "學習",
                pinyin: "xue2 xi2",
                formattedPinyin: "Xué xí",
                meanings: ["to study", "to learn"],
                radical: "子",
                hskLevel: 1,
                pos: ["verb"]
            )
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (WordOfTheDayEntry) -> Void) {
        let entry = WordOfTheDayEntry(
            date: Date(),
            word: WordOfTheDayManager.shared.getWord(for: Date())
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<WordOfTheDayEntry>) -> Void) {
        let currentDate = Date()
        let word = WordOfTheDayManager.shared.getWord(for: currentDate)
        let entry = WordOfTheDayEntry(date: currentDate, word: word)

        // Schedule reload at next midnight
        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        )
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

public struct WordOfTheDayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WordOfTheDayEntry

    private var deepLinkURL: URL? {
        let encoded = entry.word.simplified.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entry.word.simplified
        return URL(string: "shengci://word?simplified=\(encoded)")
    }

    public var body: some View {
        ZStack {
            if family != .accessoryRectangular && family != .accessoryInline {
                Color(red: 0.97, green: 0.95, blue: 0.92) // Cream background for home screen widgets
                    .ignoresSafeArea()
            }

            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryInline:
                accessoryInlineView
            @unknown default:
                mediumWidgetView
            }
        }
        .widgetURL(deepLinkURL)
    }

    // MARK: - Small Widget View
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WORD OF THE DAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                    .tracking(0.5)

                Spacer()

                Text("HSK \(entry.word.hskLevel)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.24, green: 0.35, blue: 0.65).opacity(0.12))
                    .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                    .cornerRadius(4)
            }

            Spacer(minLength: 0)

            Text(entry.word.simplified)
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(entry.word.formattedPinyin)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                .lineLimit(1)

            if let firstMeaning = entry.word.meanings.first {
                Text(firstMeaning)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.75))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: - Medium Widget View
    private var mediumWidgetView: some View {
        HStack(spacing: 16) {
            // Left Column: Character block
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("WORD OF THE DAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                        .tracking(0.5)

                    Text("• HSK \(entry.word.hskLevel)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65).opacity(0.8))
                }

                Spacer()

                Text(entry.word.simplified)
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(entry.word.formattedPinyin)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                    .lineLimit(1)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.15))

            // Right Column: Meanings & Radical
            VStack(alignment: .leading, spacing: 8) {
                if !entry.word.radical.isEmpty {
                    HStack(spacing: 4) {
                        Text("Radical:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.6))
                        Text(entry.word.radical)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
                    }
                }

                if !entry.word.pos.isEmpty {
                    Text(entry.word.pos.joined(separator: ", ").uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                }

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(entry.word.meanings.prefix(3).enumerated()), id: \.offset) { idx, meaning in
                        Text("\(idx + 1). \(meaning)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.85))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    // MARK: - Large Widget View
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORD OF THE DAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                        .tracking(0.5)
                    Text(Date(), style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.5))
                }

                Spacer()

                Text("HSK Level \(entry.word.hskLevel)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.24, green: 0.35, blue: 0.65).opacity(0.12))
                    .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                    .cornerRadius(6)
            }

            HStack(spacing: 16) {
                Text(entry.word.simplified)
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.word.formattedPinyin)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))

                    if !entry.word.traditional.isEmpty && entry.word.traditional != entry.word.simplified {
                        Text("Traditional: \(entry.word.traditional)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.6))
                    }

                    if !entry.word.radical.isEmpty {
                        Text("Radical: \(entry.word.radical)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("DEFINITIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.5))

                ForEach(Array(entry.word.meanings.prefix(4).enumerated()), id: \.offset) { idx, meaning in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.24, green: 0.35, blue: 0.65))
                        Text(meaning)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.85))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    // MARK: - Lockscreen Rectangular
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.word.simplified)
                    .font(.headline)
                Text(entry.word.formattedPinyin)
                    .font(.subheadline)
            }
            if let firstMeaning = entry.word.meanings.first {
                Text(firstMeaning)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Lockscreen Inline
    private var accessoryInlineView: some View {
        Text("\(entry.word.simplified) (\(entry.word.formattedPinyin)): \(entry.word.meanings.first ?? "")")
    }
}

struct CustomWidgetBackgroundView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .accessoryRectangular || family == .accessoryInline {
            Color.clear
        } else {
            Color(red: 0.97, green: 0.95, blue: 0.92)
        }
    }
}

public struct shengciWidget: Widget {
    let kind: String = "shengciWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordOfTheDayProvider()) { entry in
            if #available(iOS 17.0, *) {
                WordOfTheDayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        CustomWidgetBackgroundView()
                    }
            } else {
                WordOfTheDayWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Word of the Day")
        .description("Learn a new HSK Chinese word every day.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
