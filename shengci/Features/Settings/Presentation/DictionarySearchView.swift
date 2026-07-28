import Foundation
import SwiftUI

struct CEDICTEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let traditional: String
    let simplified: String
    let pinyin: String
    let definitions: [String]
}

struct CEDICTSearchResult: Sendable {
    nonisolated static let empty = CEDICTSearchResult(entries: [], hasMore: false)

    let entries: [CEDICTEntry]
    let hasMore: Bool
}

struct CEDICTSearchIndex: Sendable {
    private struct IndexedKey: Sendable {
        let key: String
        let entryPosition: Int
    }

    private let entries: [CEDICTEntry]
    private let simplifiedIndex: [IndexedKey]
    private let traditionalIndex: [IndexedKey]
    private let pinyinIndex: [IndexedKey]
    private let englishIndex: [IndexedKey]

    nonisolated init(entries: [CEDICTEntry]) {
        self.entries = entries

        var simplifiedIndex: [IndexedKey] = []
        var traditionalIndex: [IndexedKey] = []
        var pinyinIndex: [IndexedKey] = []
        var englishIndex: [IndexedKey] = []

        simplifiedIndex.reserveCapacity(entries.count)
        traditionalIndex.reserveCapacity(entries.count)
        pinyinIndex.reserveCapacity(entries.count)

        for (entryPosition, entry) in entries.enumerated() {
            simplifiedIndex.append(
                IndexedKey(key: entry.simplified, entryPosition: entryPosition)
            )
            traditionalIndex.append(
                IndexedKey(key: entry.traditional, entryPosition: entryPosition)
            )
            pinyinIndex.append(
                IndexedKey(
                    key: CEDICT.normalizePinyin(entry.pinyin),
                    entryPosition: entryPosition
                )
            )

            let tokens = entry.definitions
                .flatMap { definition in
                    definition.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                }
                .map { $0.lowercased() }

            for token in Set(tokens) {
                englishIndex.append(
                    IndexedKey(key: token, entryPosition: entryPosition)
                )
            }
        }

        self.simplifiedIndex = Self.sorted(simplifiedIndex)
        self.traditionalIndex = Self.sorted(traditionalIndex)
        self.pinyinIndex = Self.sorted(pinyinIndex)
        self.englishIndex = Self.sorted(englishIndex)
    }

    nonisolated func search(
        _ query: String,
        limit: Int = 100
    ) -> CEDICTSearchResult {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .empty }

        let pinyinQuery = CEDICT.normalizePinyin(query)
        let englishQuery = query.lowercased()
        var matchingPositions = Set<Int>()

        addMatches(for: query, from: simplifiedIndex, to: &matchingPositions)
        addMatches(for: query, from: traditionalIndex, to: &matchingPositions)
        addMatches(for: pinyinQuery, from: pinyinIndex, to: &matchingPositions)
        addMatches(for: englishQuery, from: englishIndex, to: &matchingPositions)

        guard !Task.isCancelled else { return .empty }

        let orderedPositions = matchingPositions.sorted()
        let hasMore = orderedPositions.count > limit
        let results = orderedPositions.prefix(limit).map { entries[$0] }
        return CEDICTSearchResult(entries: results, hasMore: hasMore)
    }

    nonisolated private static func sorted(_ index: [IndexedKey]) -> [IndexedKey] {
        index.sorted { lhs, rhs in
            lhs.key == rhs.key
                ? lhs.entryPosition < rhs.entryPosition
                : lhs.key < rhs.key
        }
    }

    nonisolated private func addMatches(
        for prefix: String,
        from index: [IndexedKey],
        to matchingPositions: inout Set<Int>
    ) {
        guard !prefix.isEmpty else { return }

        var position = lowerBound(for: prefix, in: index)
        var checkedEntries = 0

        while position < index.count, index[position].key.hasPrefix(prefix) {
            if checkedEntries.isMultiple(of: 256), Task.isCancelled {
                return
            }
            matchingPositions.insert(index[position].entryPosition)
            position += 1
            checkedEntries += 1
        }
    }

    nonisolated private func lowerBound(
        for key: String,
        in index: [IndexedKey]
    ) -> Int {
        var lower = 0
        var upper = index.count

        while lower < upper {
            let midpoint = lower + (upper - lower) / 2
            if index[midpoint].key < key {
                lower = midpoint + 1
            } else {
                upper = midpoint
            }
        }

        return lower
    }
}

enum CEDICT {
    nonisolated static func load(from url: URL) throws -> [CEDICTEntry] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .split(whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { parse(String($0.element), id: $0.offset) }
    }

    nonisolated static func parse(_ line: String, id: Int = 0) -> CEDICTEntry? {
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

    nonisolated static func normalizePinyin(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .filter { !$0.isNumber }
    }
}

struct DictionarySearchView: View {
    @State private var query = ""
    @State private var searchIndex: CEDICTSearchIndex?
    @State private var results = CEDICTSearchResult.empty
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
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
        .task(id: query) { await searchDictionary() }
    }

    @MainActor
    private func loadDictionary() async {
        guard let url = Bundle.main.url(forResource: "cedict_ts", withExtension: "u8") else {
            loadError = "The bundled CC-CEDICT file could not be found."
            isLoading = false
            return
        }

        do {
            searchIndex = try await Task.detached {
                let entries = try CEDICT.load(from: url)
                return CEDICTSearchIndex(entries: entries)
            }.value
        } catch {
            loadError = "The bundled CC-CEDICT file could not be read."
        }
        isLoading = false
    }

    @MainActor
    private func searchDictionary() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let searchIndex else {
            results = .empty
            return
        }

        let searchTask = Task.detached(priority: .userInitiated) {
            searchIndex.search(query)
        }
        let searchResults = await withTaskCancellationHandler {
            await searchTask.value
        } onCancel: {
            searchTask.cancel()
        }

        guard !Task.isCancelled else { return }
        results = searchResults
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

                Text(PinyinFormatter.display(entry.pinyin))
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
