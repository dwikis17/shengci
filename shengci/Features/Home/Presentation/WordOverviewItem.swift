import Foundation

struct WordOverviewItem: Identifiable, Sendable {
    let id: UUID
    let simplified: String
    let pinyin: String

    init(word: WordModel) {
        id = word.id
        simplified = word.simplified
        pinyin = word.forms.first.map {
            PinyinFormatter.display($0.transcriptions.pinyin)
        } ?? ""
    }
}
