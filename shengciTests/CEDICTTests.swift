import Foundation
import Testing
@testable import shengci

private final class LoaderCounter: @unchecked Sendable {
    private var count = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

private func makeTempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

struct CEDICTTests {
    private let entries = [
        CEDICTEntry(id: 0, traditional: "你好", simplified: "你好", pinyin: "ni3 hao3", definitions: ["hello", "hi"]),
        CEDICTEntry(id: 1, traditional: "妳", simplified: "你", pinyin: "ni3", definitions: ["you (female)"]),
        CEDICTEntry(id: 2, traditional: "好", simplified: "好", pinyin: "hao3", definitions: ["good", "well"]),
    ]

    @Test func parsesEntriesAndSkipsComments() {
        #expect(CEDICT.parse("# CC-CEDICT") == nil)
        let entry = CEDICT.parse("傳統 简体 [ni3 hao3] /hello/hi/", id: 7)
        #expect(entry == CEDICTEntry(id: 7, traditional: "傳統", simplified: "简体", pinyin: "ni3 hao3", definitions: ["hello", "hi"]))
    }

    @Test func searchesChineseToneFreePinyinAndEnglishPrefixes() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleEntries = entries
        let store = CEDICTStore(databaseDirectory: tempDir, loader: { sampleEntries })

        try await store.prepare()

        let search1 = await store.search(query: "你")
        #expect(search1.entries.count == 2)

        let search2 = await store.search(query: "nǐ")
        #expect(search2.entries.count == 2)

        let search3 = await store.search(query: "ni3")
        #expect(search3.entries.count == 2)

        let search4 = await store.search(query: "hel")
        #expect(search4.entries.map(\.simplified) == ["你好"])
    }

    @Test func capsResultsAndMaintainsSourceOrder() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let many = (0..<101).map { CEDICTEntry(id: $0, traditional: "字\($0)", simplified: "字\($0)", pinyin: "zi4", definitions: ["character"]) }
        let store = CEDICTStore(databaseDirectory: tempDir, loader: { many })

        try await store.prepare()

        let results = await store.search(query: "字")
        #expect(results.entries.count == 100)
        #expect(results.hasMore)
        #expect(results.entries.first?.id == 0)
        #expect(results.entries.last?.id == 99)
    }

    @Test func formatsNumberedPinyinWithToneMarks() {
        #expect(PinyinFormatter.display("ma1 ma2 ma3 ma4 ma5") == "mā má mǎ mà ma")
        #expect(PinyinFormatter.display("ni3 hao3") == "nǐ hǎo")
        #expect(PinyinFormatter.display("liu2 gui1 nü3 lu:4 nv3") == "liú guī nǚ lǜ nǚ")
        #expect(PinyinFormatter.display("Zhong1 Guo2") == "Zhōng Guó")
        #expect(PinyinFormatter.display("nǐ hǎo 110") == "nǐ hǎo 110")
    }

    @Test func handwritingCandidatesKeepOnlyUniqueSingleHanzi() {
        let candidates = HandwritingCandidateFilter.singleHanzi(
            from: ["你", "你", "好", "hello", "你好", "A", "学"],
            limit: 2
        )

        #expect(candidates == ["你", "好"])
    }

    @Test func dictionaryScopesDoNotExposeASeparateDrawMode() {
        #expect(SearchScope.allCases == [.all, .hanzi, .pinyin, .english])
    }

    @Test func concurrentWarmAndPrepareCallsCreateOneTask() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = LoaderCounter()
        let sampleEntries = entries
        let store = CEDICTStore(databaseDirectory: tempDir, loader: {
            _ = counter.increment()
            try await Task.sleep(nanoseconds: 50_000_000)
            return sampleEntries
        })

        async let warmCall: () = store.warm()
        async let prepareCall: () = store.prepare()

        _ = await warmCall
        try await prepareCall

        #expect(counter.value == 1)
        let searchResult = await store.search(query: "你好")
        #expect(searchResult.entries.count == 1)
    }

    @Test func completedWarmUpReturnsCachedDatabaseWithoutReloading() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = LoaderCounter()
        let sampleEntries = entries
        let store = CEDICTStore(databaseDirectory: tempDir, loader: {
            _ = counter.increment()
            return sampleEntries
        })

        await store.warm()
        try await store.prepare()
        try await store.prepare()

        #expect(counter.value == 1)
        let firstResult = await store.search(query: "你好")
        let secondResult = await store.search(query: "你好")

        #expect(firstResult.entries.count == 1)
        #expect(secondResult.entries.count == 1)
    }

    @Test func reopeningSameCacheKeyReusesDatabaseWithoutParsing() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = LoaderCounter()
        let sampleEntries = entries

        let store1 = CEDICTStore(databaseDirectory: tempDir, schemaVersion: 1, buildVersion: "1.0", loader: {
            _ = counter.increment()
            return sampleEntries
        })
        try await store1.prepare()
        #expect(counter.value == 1)

        let store2 = CEDICTStore(databaseDirectory: tempDir, schemaVersion: 1, buildVersion: "1.0", loader: {
            _ = counter.increment()
            return sampleEntries
        })
        try await store2.prepare()
        #expect(counter.value == 1) // Loader not called again!

        let search = await store2.search(query: "你好")
        #expect(search.entries.count == 1)
    }

    @Test func newAppBuildOrSchemaKeyRebuildsDatabase() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = LoaderCounter()
        let sampleEntries = entries

        let store1 = CEDICTStore(databaseDirectory: tempDir, schemaVersion: 1, buildVersion: "1.0", loader: {
            _ = counter.increment()
            return sampleEntries
        })
        try await store1.prepare()
        #expect(counter.value == 1)

        let store2 = CEDICTStore(databaseDirectory: tempDir, schemaVersion: 2, buildVersion: "1.0", loader: {
            _ = counter.increment()
            return sampleEntries
        })
        try await store2.prepare()
        #expect(counter.value == 2) // Rebuilt because schema version changed!
    }

    @Test func failedLoadClearsInFlightStateAndAllowsRetry() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = LoaderCounter()
        let sampleEntries = entries
        let store = CEDICTStore(databaseDirectory: tempDir, loader: {
            let current = counter.increment()
            if current == 1 {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
            return sampleEntries
        })

        await #expect(throws: Error.self) {
            try await store.prepare()
        }

        try await store.prepare()
        #expect(counter.value == 2)
        let result = await store.search(query: "你好")
        #expect(result.entries.count == 1)
    }
}

