import Foundation
import SwiftData

@Model
final class PracticedWord {
    @Attribute(.unique) var id: String
    var simplified: String
    var hskLevel: Int
    var pinyin: String
    var traditional: String
    var meaningsData: String
    var lastPracticedAt: Date
    var timesPracticed: Int
    var correctCount: Int
    var incorrectCount: Int

    init(
        simplified: String,
        hskLevel: Int,
        pinyin: String,
        traditional: String = "",
        meanings: [String] = [],
        lastPracticedAt: Date = Date(),
        timesPracticed: Int = 1,
        correctCount: Int = 1,
        incorrectCount: Int = 0
    ) {
        self.id = "\(hskLevel)_\(simplified)"
        self.simplified = simplified
        self.hskLevel = hskLevel
        self.pinyin = pinyin
        self.traditional = traditional
        self.meaningsData = meanings.joined(separator: "||")
        self.lastPracticedAt = lastPracticedAt
        self.timesPracticed = timesPracticed
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
    }

    var meanings: [String] {
        meaningsData.isEmpty ? [] : meaningsData.components(separatedBy: "||")
    }
}
