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
        let index = CEDICTSearchIndex(entries: entries)

        #expect(index.search("你").entries.count == 2)
        #expect(index.search("nǐ").entries.count == 2)
        #expect(index.search("ni3").entries.count == 2)
        #expect(index.search("hel").entries.map(\.simplified) == ["你好"])
    }

    @Test func capsResults() {
        let many = (0..<101).map { CEDICTEntry(id: $0, traditional: "字\($0)", simplified: "字\($0)", pinyin: "zi4", definitions: ["character"]) }
        let results = CEDICTSearchIndex(entries: many).search("字")
        #expect(results.entries.count == 100)
        #expect(results.hasMore)
    }

    @Test func formatsNumberedPinyinWithToneMarks() {
        #expect(PinyinFormatter.display("ma1 ma2 ma3 ma4 ma5") == "mā má mǎ mà ma")
        #expect(PinyinFormatter.display("ni3 hao3") == "nǐ hǎo")
        #expect(PinyinFormatter.display("liu2 gui1 nü3 lu:4 nv3") == "liú guī nǚ lǜ nǚ")
        #expect(PinyinFormatter.display("Zhong1 Guo2") == "Zhōng Guó")
        #expect(PinyinFormatter.display("nǐ hǎo 110") == "nǐ hǎo 110")
    }
}
