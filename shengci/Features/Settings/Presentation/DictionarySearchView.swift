import Foundation
import SQLite3
import SwiftUI

nonisolated struct CEDICTEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let traditional: String
    let simplified: String
    let pinyin: String
    let definitions: [String]
}

nonisolated struct CEDICTSearchResult: Sendable {
    nonisolated static let empty = CEDICTSearchResult(entries: [], hasMore: false)

    let entries: [CEDICTEntry]
    let hasMore: Bool
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

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case hanzi = "Hanzi"
    case pinyin = "Pinyin"
    case english = "English"

    var id: String { rawValue }
}

nonisolated final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?

    init(path: String, readOnly: Bool) throws {
        let flags = readOnly
            ? (SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let errorMsg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLiteDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    deinit {
        if let db {
            sqlite3_close_v2(db)
        }
    }

    func execute(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errmsg) != SQLITE_OK {
            let message = errmsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errmsg)
            throw NSError(domain: "SQLiteDatabase", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    func createSchema() throws {
        let sql = """
        PRAGMA journal_mode = MEMORY;
        PRAGMA synchronous = OFF;

        CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY,
            simplified TEXT NOT NULL,
            traditional TEXT NOT NULL,
            pinyin TEXT NOT NULL,
            pinyin_normalized TEXT NOT NULL,
            definitions TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_entries_simplified ON entries(simplified);
        CREATE INDEX IF NOT EXISTS idx_entries_traditional ON entries(traditional);
        CREATE INDEX IF NOT EXISTS idx_entries_pinyin_norm ON entries(pinyin_normalized);

        CREATE TABLE IF NOT EXISTS english_tokens (
            token TEXT NOT NULL,
            entry_id INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_english_tokens_token ON english_tokens(token);
        """
        try execute(sql)
    }

    func insert(entries: [CEDICTEntry]) throws {
        try execute("BEGIN TRANSACTION;")

        var stmtEntries: OpaquePointer?
        let sqlEntries = "INSERT INTO entries (id, simplified, traditional, pinyin, pinyin_normalized, definitions) VALUES (?, ?, ?, ?, ?, ?);"
        guard sqlite3_prepare_v2(db, sqlEntries, -1, &stmtEntries, nil) == SQLITE_OK, let stmtEntries else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Error preparing entry statement"
            try? execute("ROLLBACK;")
            throw NSError(domain: "SQLiteDatabase", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmtEntries) }

        var stmtTokens: OpaquePointer?
        let sqlTokens = "INSERT INTO english_tokens (token, entry_id) VALUES (?, ?);"
        guard sqlite3_prepare_v2(db, sqlTokens, -1, &stmtTokens, nil) == SQLITE_OK, let stmtTokens else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Error preparing token statement"
            try? execute("ROLLBACK;")
            throw NSError(domain: "SQLiteDatabase", code: 4, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmtTokens) }

        let encoder = JSONEncoder()

        for entry in entries {
            let normalizedPinyin = CEDICT.normalizePinyin(entry.pinyin)
            let jsonDefsData = (try? encoder.encode(entry.definitions)) ?? Data()
            let jsonDefs = String(data: jsonDefsData, encoding: .utf8) ?? "[]"

            sqlite3_bind_int64(stmtEntries, 1, Int64(entry.id))
            sqlite3_bind_text(stmtEntries, 2, entry.simplified, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmtEntries, 3, entry.traditional, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmtEntries, 4, entry.pinyin, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmtEntries, 5, normalizedPinyin, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmtEntries, 6, jsonDefs, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmtEntries) != SQLITE_DONE {
                let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Error inserting entry"
                try? execute("ROLLBACK;")
                throw NSError(domain: "SQLiteDatabase", code: 5, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            sqlite3_reset(stmtEntries)

            let englishTokens = Set(
                entry.definitions
                    .flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) }
                    .map { $0.lowercased() }
            )

            for token in englishTokens {
                sqlite3_bind_text(stmtTokens, 1, token, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmtTokens, 2, Int64(entry.id))

                if sqlite3_step(stmtTokens) != SQLITE_DONE {
                    let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Error inserting token"
                    try? execute("ROLLBACK;")
                    throw NSError(domain: "SQLiteDatabase", code: 6, userInfo: [NSLocalizedDescriptionKey: msg])
                }
                sqlite3_reset(stmtTokens)
            }
        }

        try execute("COMMIT;")
    }

    func countEntries() throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM entries;", -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "SQLiteDatabase", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare count query"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    func search(query: String, scope: SearchScope = .all, limit: Int = 100) -> CEDICTSearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return .empty }

        let pinyinQuery = CEDICT.normalizePinyin(trimmedQuery)
        let englishQuery = trimmedQuery.lowercased()
        let likePattern = "%\(trimmedQuery)%"
        let pinyinLikePattern = "%\(pinyinQuery)%"
        let englishLikePattern = "%\(englishQuery)%"

        var matchingIDs = Set<Int>()

        if scope == .all || scope == .hanzi {
            // 1. Simplified & Traditional Chinese substring
            addMatchingIDs(
                sql: "SELECT id FROM entries WHERE simplified LIKE ? OR traditional LIKE ?;",
                patterns: [likePattern, likePattern],
                into: &matchingIDs
            )
        }

        if scope == .all || scope == .pinyin {
            // 2. Pinyin normalized & space-insensitive compact substring matching
            if !pinyinQuery.isEmpty {
                let compactPinyinQuery = pinyinQuery.filter { !$0.isWhitespace }
                let compactPinyinPattern = "%\(compactPinyinQuery)%"
                addMatchingIDs(
                    sql: "SELECT id FROM entries WHERE pinyin_normalized LIKE ? OR REPLACE(pinyin_normalized, ' ', '') LIKE ?;",
                    patterns: [pinyinLikePattern, compactPinyinPattern],
                    into: &matchingIDs
                )
            }
        }

        if scope == .all || scope == .english {
            // 3. English definition substring & token matching
            if !englishQuery.isEmpty {
                addMatchingIDs(
                    sql: "SELECT id FROM entries WHERE definitions LIKE ?;",
                    patterns: [englishLikePattern],
                    into: &matchingIDs
                )
                addMatchingIDs(
                    sql: "SELECT entry_id FROM english_tokens WHERE token LIKE ?;",
                    patterns: ["\(englishQuery)%"],
                    into: &matchingIDs
                )
            }
        }

        guard !Task.isCancelled else { return .empty }

        let sortedIDs = matchingIDs.sorted()
        let hasMore = sortedIDs.count > limit
        let pageIDs = Array(sortedIDs.prefix(limit))
        if pageIDs.isEmpty {
            return .empty
        }

        let entries = fetchEntries(for: pageIDs)
        return CEDICTSearchResult(entries: entries, hasMore: hasMore)
    }

    private func addMatchingIDs(sql: String, patterns: [String], into matchingIDs: inout Set<Int>) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }

        for (index, pattern) in patterns.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), pattern, -1, SQLITE_TRANSIENT)
        }

        var checkCounter = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            checkCounter += 1
            if checkCounter.isMultiple(of: 256), Task.isCancelled {
                return
            }
            let entryID = Int(sqlite3_column_int64(stmt, 0))
            matchingIDs.insert(entryID)
        }
    }

    private func fetchEntries(for pageIDs: [Int]) -> [CEDICTEntry] {
        guard !pageIDs.isEmpty else { return [] }
        let placeholders = pageIDs.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, traditional, simplified, pinyin, definitions FROM entries WHERE id IN (\(placeholders)) ORDER BY id ASC;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (index, id) in pageIDs.enumerated() {
            sqlite3_bind_int64(stmt, Int32(index + 1), Int64(id))
        }

        var results: [CEDICTEntry] = []
        results.reserveCapacity(pageIDs.count)

        let decoder = JSONDecoder()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(stmt, 0))
            let trad = String(cString: sqlite3_column_text(stmt, 1))
            let simp = String(cString: sqlite3_column_text(stmt, 2))
            let pin = String(cString: sqlite3_column_text(stmt, 3))
            let defsStr = String(cString: sqlite3_column_text(stmt, 4))
            let defsData = defsStr.data(using: .utf8) ?? Data()
            let defs = (try? decoder.decode([String].self, from: defsData)) ?? []

            results.append(CEDICTEntry(id: id, traditional: trad, simplified: simp, pinyin: pin, definitions: defs))
        }

        return results
    }
}

actor CEDICTStore {
    static let shared = CEDICTStore()

    private var database: SQLiteDatabase?
    private var buildTask: Task<Void, Error>?

    private let databaseDirectory: URL
    private let sourceURL: URL?
    private let schemaVersion: Int
    private let buildVersion: String
    private let loader: (@Sendable () async throws -> [CEDICTEntry])?

    init(
        databaseDirectory: URL? = nil,
        sourceURL: URL? = nil,
        schemaVersion: Int = 1,
        buildVersion: String? = nil,
        loader: (@Sendable () async throws -> [CEDICTEntry])? = nil
    ) {
        let appSupport = databaseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.databaseDirectory = appSupport
        self.sourceURL = sourceURL ?? Bundle.main.url(forResource: "cedict_ts", withExtension: "u8")
        self.schemaVersion = schemaVersion
        self.buildVersion = buildVersion ?? (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
        self.loader = loader
    }

    func warm() {
        _ = fetchOrStartBuildTask(priority: .utility)
    }

    func prepare() async throws {
        if database != nil {
            return
        }
        let task = fetchOrStartBuildTask(priority: .userInitiated)
        try await task.value
    }

    func search(query: String, scope: SearchScope = .all, limit: Int = 100) async -> CEDICTSearchResult {
        if database == nil {
            do {
                try await prepare()
            } catch {
                return .empty
            }
        }
        guard let database else { return .empty }
        return database.search(query: query, scope: scope, limit: limit)
    }

    private func fetchOrStartBuildTask(priority: TaskPriority) -> Task<Void, Error> {
        if database != nil {
            return Task {}
        }
        if let existingTask = buildTask {
            return existingTask
        }

        let databaseDirectory = self.databaseDirectory
        let sourceURL = self.sourceURL
        let schemaVersion = self.schemaVersion
        let buildVersion = self.buildVersion
        let loader = self.loader

        let task = Task.detached(priority: priority) {
            try await CEDICTStore.performBuild(
                databaseDirectory: databaseDirectory,
                sourceURL: sourceURL,
                schemaVersion: schemaVersion,
                buildVersion: buildVersion,
                loader: loader
            )
        }
        buildTask = task

        Task { [weak self] in
            do {
                try await task.value
                let dbPath = databaseDirectory.appendingPathComponent(
                    CEDICTStore.cacheFileName(schemaVersion: schemaVersion, buildVersion: buildVersion)
                ).path
                let db = try SQLiteDatabase(path: dbPath, readOnly: true)
                await self?.didComplete(database: db)
            } catch {
                await self?.didFail()
            }
        }

        return task
    }

    private func didComplete(database: SQLiteDatabase) {
        self.database = database
        self.buildTask = nil
    }

    private func didFail() {
        self.database = nil
        self.buildTask = nil
    }

    private static func cacheFileName(schemaVersion: Int, buildVersion: String) -> String {
        "dictionary-v\(schemaVersion)-\(buildVersion).sqlite"
    }

    private static func performBuild(
        databaseDirectory: URL,
        sourceURL: URL?,
        schemaVersion: Int,
        buildVersion: String,
        loader: (@Sendable () async throws -> [CEDICTEntry])?
    ) async throws {
        let fm = FileManager.default
        try? fm.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)

        let targetFileName = cacheFileName(schemaVersion: schemaVersion, buildVersion: buildVersion)
        let destinationURL = databaseDirectory.appendingPathComponent(targetFileName)
        let stagingURL = databaseDirectory.appendingPathComponent(targetFileName + ".staging")

        // 1. Clean up old databases in databaseDirectory that don't match current cacheFileName
        if let files = try? fm.contentsOfDirectory(at: databaseDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                let name = file.lastPathComponent
                if name.hasPrefix("dictionary-v") && name != targetFileName && name != targetFileName + ".staging" {
                    try? fm.removeItem(at: file)
                }
            }
        }

        // 2. If destination already exists, validate it
        if fm.fileExists(atPath: destinationURL.path) {
            do {
                let testDB = try SQLiteDatabase(path: destinationURL.path, readOnly: true)
                let count = try testDB.countEntries()
                if count > 0 {
                    return // Valid database exists
                }
            } catch {
                try? fm.removeItem(at: destinationURL)
            }
        }

        // 3. Clean up staging file before build
        try? fm.removeItem(at: stagingURL)

        // 4. Load entries
        let entries: [CEDICTEntry]
        if let loader {
            entries = try await loader()
        } else if let sourceURL {
            entries = try CEDICT.load(from: sourceURL)
        } else {
            throw NSError(domain: "CEDICT", code: 404, userInfo: [NSLocalizedDescriptionKey: "The bundled CC-CEDICT file could not be found."])
        }

        // 5. Build into staging file
        do {
            let stagingDB = try SQLiteDatabase(path: stagingURL.path, readOnly: false)
            try stagingDB.createSchema()
            try stagingDB.insert(entries: entries)
            // Close stagingDB handle on deinit
        } catch {
            try? fm.removeItem(at: stagingURL)
            throw error
        }

        // 6. Validate staging file
        do {
            let validationDB = try SQLiteDatabase(path: stagingURL.path, readOnly: true)
            let count = try validationDB.countEntries()
            guard count > 0 else {
                throw NSError(domain: "CEDICT", code: 500, userInfo: [NSLocalizedDescriptionKey: "Staging database contains no entries."])
            }
        } catch {
            try? fm.removeItem(at: stagingURL)
            throw error
        }

        // 7. Atomic replace
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.moveItem(at: stagingURL, to: destinationURL)
    }
}

struct DictionarySearchView: View {
    @State private var query = ""
    @State private var searchScope: SearchScope = .all
    @State private var isDrawingHanzi = false
    @State private var results = CEDICTSearchResult.empty
    @State private var isLoading = true
    @State private var loadError: String?
    @FocusState private var isSearchFocused: Bool

    init() {
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor(Color.royalBlueAccent)
        appearance.backgroundColor = UIColor(Color.warmIvoryCard)
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.black.withAlphaComponent(0.75), .font: UIFont.systemFont(ofSize: 13, weight: .medium)],
            for: .normal
        )
    }

    var body: some View {
        ZStack {
            Color.creamBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if !isLoading && loadError == nil {
                    HStack(spacing: 8) {
                        Picker("Search Scope", selection: $searchScope) {
                            ForEach(SearchScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)

                        if searchScope == .hanzi {
                            Button {
                                isDrawingHanzi.toggle()
                                isSearchFocused = !isDrawingHanzi
                            } label: {
                                Image(systemName: isDrawingHanzi ? "pencil.slash" : "pencil")
                                    .font(.subheadline)
                                    .foregroundColor(isDrawingHanzi ? Color.royalBlueAccent : Color.darkForeground.opacity(0.6))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isDrawingHanzi ? Color.royalBlueAccent.opacity(0.12) : Color.warmIvoryCard)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(isDrawingHanzi ? Color.royalBlueAccent.opacity(0.25) : Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isDrawingHanzi ? "Close Hanzi drawing" : "Draw Hanzi")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .onChange(of: searchScope) { newScope in
                        if newScope != .hanzi {
                            isDrawingHanzi = false
                        }
                    }
                }

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color.darkForeground)
                        Text("Loading dictionary…")
                            .font(.headline)
                            .foregroundColor(Color.darkForeground.opacity(0.8))
                    }
                    .frame(maxHeight: .infinity)
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

                        Button {
                            Task { await loadDictionary() }
                        } label: {
                            Text("Retry")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.royalBlueAccent)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxHeight: .infinity)
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
                        Text("Try searching with different keywords or switching search scope.")
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

                if isDrawingHanzi && searchScope == .hanzi {
                    HandwritingCanvasView(
                        recognizer: ChineseHandwritingRecognizer.shared,
                        onSelectCandidate: { candidate in
                            query += candidate
                        }
                    )
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
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Chinese, pinyin, or English"
        )
        .focused($isSearchFocused)
        .task { await loadDictionary() }
        .task(id: "\(query)_\(searchScope.rawValue)") { await searchDictionary() }
    }

    @MainActor
    private func loadDictionary() async {
        isLoading = true
        loadError = nil
        do {
            try await CEDICTStore.shared.prepare()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func searchDictionary() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = .empty
            return
        }

        let searchResults = await CEDICTStore.shared.search(query: trimmedQuery, scope: searchScope)
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
