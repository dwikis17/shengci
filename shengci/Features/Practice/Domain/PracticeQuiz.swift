import Foundation

struct PracticeQuestion: Identifiable {
    let word: WordModel
    let choices: [String]

    var id: UUID { word.id }
    var meanings: Set<String> { Set(word.forms.first?.meanings ?? []) }

    func isCorrect(_ choice: String) -> Bool {
        meanings.contains(choice)
    }
}

enum PracticeQuiz {
    static func makeQuestions(
        from words: [WordModel],
        distractorPool: [WordModel] = [],
        count: Int = 10
    ) -> [PracticeQuestion] {
        let eligibleWords = uniqueEligibleWords(from: words)
        let pool = distractorPool.isEmpty ? eligibleWords : uniqueEligibleWords(from: distractorPool)
        return eligibleWords.shuffled().prefix(count).map {
            PracticeQuestion(word: $0, choices: choices(for: $0, from: pool))
        }
    }

    static func choices(for word: WordModel, from words: [WordModel]) -> [String] {
        let correctMeanings = Set(word.forms.first?.meanings ?? [])
        guard let correctChoice = correctMeanings.randomElement() else { return [] }

        let distractors = Set(
            words
                .filter { $0.id != word.id }
                .flatMap { $0.forms.first?.meanings ?? [] }
                .filter { !correctMeanings.contains($0) }
        )
        return ([correctChoice] + distractors.shuffled().prefix(3)).shuffled()
    }

    private static func uniqueEligibleWords(from words: [WordModel]) -> [WordModel] {
        var seen = Set<String>()
        return words.filter { word in
            guard let meanings = word.forms.first?.meanings, !meanings.isEmpty else {
                return false
            }
            return seen.insert(word.simplified).inserted
        }
    }
}
