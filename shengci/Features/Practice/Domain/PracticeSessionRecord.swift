import Foundation
import SwiftData

struct SessionWordItem: Codable, Identifiable {
    var id: String { "\(simplified)_\(pinyin)" }
    let simplified: String
    let traditional: String
    let pinyin: String
    let meanings: [String]
    let isCorrect: Bool
    let selectedChoice: String?
}

@Model
final class PracticeSessionRecord {
    @Attribute(.unique) var id: UUID
    var hskLevel: Int
    var date: Date
    var score: Int
    var totalQuestions: Int
    var itemsJSON: String

    init(
        id: UUID = UUID(),
        hskLevel: Int,
        date: Date = Date(),
        score: Int,
        totalQuestions: Int,
        items: [SessionWordItem]
    ) {
        self.id = id
        self.hskLevel = hskLevel
        self.date = date
        self.score = score
        self.totalQuestions = totalQuestions
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) {
            self.itemsJSON = json
        } else {
            self.itemsJSON = "[]"
        }
    }

    var items: [SessionWordItem] {
        guard let data = itemsJSON.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([SessionWordItem].self, from: data)) ?? []
    }
}
