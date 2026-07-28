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
        let rawDefinitions = fields[2][fields[2].index(after: pinyinEnd)...]
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "; ")) }
            .filter { !$0.isEmpty }

        guard !rawDefinitions.isEmpty else { return nil }
        return CEDICTEntry(
            id: id,
            traditional: String(fields[0]),
            simplified: String(fields[1]),
            pinyin: String(fields[2][pinyinStart..<pinyinEnd]),
            definitions: rawDefinitions
        )
    }

    nonisolated static func normalizePinyin(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .filter { !$0.isNumber }
    }
}

final class CEDICTStore: @unchecked Sendable {
    static let shared = CEDICTStore()
    private var loadTask: Task<CEDICTSearchIndex, Error>?
    private var cachedIndex: CEDICTSearchIndex?
    private let lock = NSLock()

    private init() {}

    func getIndex() async throws -> CEDICTSearchIndex {
        lock.lock()
        if let cachedIndex {
            lock.unlock()
            return cachedIndex
        }
        if let existingTask = loadTask {
            lock.unlock()
            return try await existingTask.value
        }

        let task = Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: "cedict_ts", withExtension: "u8") else {
                throw NSError(
                    domain: "CEDICT",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "The bundled CC-CEDICT file could not be found."]
                )
            }
            let entries = try CEDICT.load(from: url)
            return CEDICTSearchIndex(entries: entries)
        }
        loadTask = task
        lock.unlock()

        do {
            let index = try await task.value
            lock.lock()
            cachedIndex = index
            lock.unlock()
            return index
        } catch {
            lock.lock()
            loadTask = nil
            lock.unlock()
            throw error
        }
    }

    func preload() {
        Task {
            _ = try? await getIndex()
        }
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

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.darkForeground)
                    Text("Loading dictionary…")
                        .font(.headline)
                        .foregroundColor(Color.darkForeground.opacity(0.8))
                }
            } else if let loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.amberAccent)
                    Text(loadError)
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.royalBlueAccent.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color.royalBlueAccent)
                    }
                    Text("Search the Dictionary")
                        .font(.title2.bold())
                        .foregroundColor(Color.darkForeground)
                    Text("Search Chinese characters, pinyin, or English.")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxHeight: .infinity)
            } else if results.entries.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.roseAccent.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color.roseAccent)
                    }
                    Text("No Matches Found")
                        .font(.title2.bold())
                        .foregroundColor(Color.darkForeground)
                    Text("Try searching with different keywords, pinyin, or characters.")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 12) {
                        if results.hasMore {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("Showing the first 100 matches. Refine your search for more.")
                                    .font(.caption)
                            }
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                            .padding(.vertical, 4)
                        }

                        ForEach(results.entries) { entry in
                            DictionaryEntryRow(entry: entry)
                        }

                        Text("Source: CC-CEDICT (MDBG) · CC BY-SA 4.0")
                            .font(.caption)
                            .foregroundColor(Color.darkForeground.opacity(0.5))
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Color.creamBackground,
            for: .navigationBar
        )
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $query, prompt: "Chinese, pinyin, or English")
        .task { await loadDictionary() }
        .task(id: query) { await searchDictionary() }
    }

    @MainActor
    private func loadDictionary() async {
        do {
            searchIndex = try await CEDICTStore.shared.getIndex()
        } catch {
            loadError = error.localizedDescription
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
    @State private var isSpeaking = false

    private var cleanedDefinitions: String {
        entry.definitions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "; ")) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(entry.simplified)
                    .font(.title2.bold())
                    .foregroundColor(Color.darkForeground)

                if entry.traditional != entry.simplified {
                    Text("(\(entry.traditional))")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.55))
                }

                Text(PinyinFormatter.display(entry.pinyin))
                    .font(.headline)
                    .foregroundColor(Color.royalBlueAccent)

                Spacer()

                // Audio Button
                Button {
                    SpeechSynthesizerManager.shared.speak(entry.simplified)
                    HapticManager.shared.impact(style: .light)
                    isSpeaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isSpeaking = false
                    }
                } label: {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.subheadline)
                        .foregroundColor(isSpeaking ? Color.royalBlueAccent : Color.darkForeground.opacity(0.6))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }

            Text(cleanedDefinitions)
                .font(.subheadline)
                .foregroundColor(Color.darkForeground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.warmIvoryCard)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
