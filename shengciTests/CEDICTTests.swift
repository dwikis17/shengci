import Testing
@testable import shengci

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

    @Test func searchesChineseToneFreePinyinAndEnglishPrefixes() {
        #expect(CEDICT.search("你", in: entries).entries.count == 2)
        #expect(CEDICT.search("nǐ", in: entries).entries.count == 2)
        #expect(CEDICT.search("hel", in: entries).entries.map(\.simplified) == ["你好"])
    }

    @Test func capsResults() {
        let many = (0..<101).map { CEDICTEntry(id: $0, traditional: "字\($0)", simplified: "字\($0)", pinyin: "zi4", definitions: ["character"]) }
        let results = CEDICT.search("字", in: many)
        #expect(results.entries.count == 100)
        #expect(results.hasMore)
    }
}
