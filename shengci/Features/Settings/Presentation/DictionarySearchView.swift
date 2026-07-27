import Foundation
import SwiftUI

struct CEDICTEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let traditional: String
    let simplified: String
    let pinyin: String
    let definitions: [String]
}

enum CEDICT {
    static func load(from url: URL) throws -> [CEDICTEntry] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .split(whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { parse(String($0.element), id: $0.offset) }
    }

    static func parse(_ line: String, id: Int = 0) -> CEDICTEntry? {
        guard !line.hasPrefix("#") else { return nil }
        let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard fields.count == 3,
              fields[2].first == "[",
              let pinyinEnd = fields[2].firstIndex(of: "]")
        else { return nil }

        let pinyinStart = fields[2].index(after: fields[2].startIndex)
        let definitions = fields[2][fields[2].index(after: pinyinEnd)...]
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard !definitions.isEmpty else { return nil }
        return CEDICTEntry(
            id: id,
            traditional: String(fields[0]),
            simplified: String(fields[1]),
            pinyin: String(fields[2][pinyinStart..<pinyinEnd]),
            definitions: definitions
        )
    }

    static func search(_ query: String, in entries: [CEDICTEntry], limit: Int = 100) -> (entries: [CEDICTEntry], hasMore: Bool) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return ([], false) }

        let pinyinQuery = normalizePinyin(query)
        let englishQuery = query.lowercased()
        var matches: [CEDICTEntry] = []

        // ponytail: scans 124k bundled entries per query; add an index only if profiling shows typing lag.
        for entry in entries where entry.simplified.hasPrefix(query)
            || entry.traditional.hasPrefix(query)
            || normalizePinyin(entry.pinyin).hasPrefix(pinyinQuery)
            || entry.definitions.contains(where: { definition in
                definition.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .contains { $0.lowercased().hasPrefix(englishQuery) }
            })
        {
            if matches.count == limit { return (matches, true) }
            matches.append(entry)
        }
        return (matches, false)
    }

    static func normalizePinyin(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .filter { !$0.isNumber }
    }
}

struct DictionarySearchView: View {
    @State private var query = ""
    @State private var entries: [CEDICTEntry] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        let results = CEDICT.search(query, in: entries)

        ZStack {
            Color.creamBackground.ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView("Loading dictionary…")
                } else if let loadError {
                    ContentUnavailableView("Dictionary Unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Search the Dictionary", systemImage: "magnifyingglass", description: Text("Search Chinese characters, pinyin, or English."))
                } else if results.entries.isEmpty {
                    ContentUnavailableView("No Matches", systemImage: "magnifyingglass", description: Text("Try a shorter or different search."))
                } else {
                    List {
                        if results.hasMore {
                            Text("Showing the first 100 matches. Refine your search for more.")
                                .font(.footnote)
                                .foregroundColor(Color.darkForeground.opacity(0.65))
                                .listRowBackground(Color.creamBackground)
                        }

                        ForEach(results.entries) { entry in
                            DictionaryEntryRow(entry: entry)
                                .listRowBackground(Color.warmIvoryCard)
                        }

                        Text("Source: CC-CEDICT (MDBG) · CC BY-SA 4.0")
                            .font(.caption)
                            .foregroundColor(Color.darkForeground.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.creamBackground)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Chinese, pinyin, or English")
        .task { await loadDictionary() }
    }

    @MainActor
    private func loadDictionary() async {
        guard let url = Bundle.main.url(forResource: "cedict_ts", withExtension: "u8") else {
            loadError = "The bundled CC-CEDICT file could not be found."
            isLoading = false
            return
        }

        do {
            entries = try await Task.detached { try CEDICT.load(from: url) }.value
        } catch {
            loadError = "The bundled CC-CEDICT file could not be read."
        }
        isLoading = false
    }
}

private struct DictionaryEntryRow: View {
    let entry: CEDICTEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.simplified)
                    .font(.title2.bold())
                    .foregroundColor(Color.darkForeground)

                if entry.traditional != entry.simplified {
                    Text(entry.traditional)
                        .foregroundColor(Color.darkForeground.opacity(0.55))
                }

                Text(entry.pinyin)
                    .font(.subheadline)
                    .foregroundColor(Color.royalBlueAccent)
            }

            Text(entry.definitions.joined(separator: "; "))
                .font(.subheadline)
                .foregroundColor(Color.darkForeground.opacity(0.75))
        }
        .padding(.vertical, 4)
    }
}
