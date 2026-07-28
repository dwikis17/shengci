import Foundation

enum PinyinFormatter {
    nonisolated static func display(_ value: String) -> String {
        value
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { formatSyllable(String($0)) }
            .joined(separator: " ")
    }

    nonisolated private static func formatSyllable(_ value: String) -> String {
        guard
            let toneCharacter = value.last,
            let tone = toneCharacter.wholeNumberValue,
            (1...5).contains(tone)
        else {
            return value
        }

        var syllable = String(value.dropLast())
        guard !syllable.isEmpty, syllable.allSatisfy(isPinyinCharacter) else {
            return value
        }

        syllable = syllable
            .replacingOccurrences(of: "u:", with: "ü")
            .replacingOccurrences(of: "U:", with: "Ü")
            .replacingOccurrences(of: "v", with: "ü")
            .replacingOccurrences(of: "V", with: "Ü")

        guard tone != 5 else { return syllable }

        var characters = Array(syllable)
        guard let vowelIndex = toneVowelIndex(in: characters) else {
            return value
        }

        let vowel = characters[vowelIndex]
        guard let markedVowel = toneMarkedVowel(vowel, tone: tone) else {
            return value
        }

        characters[vowelIndex] = markedVowel
        return String(characters)
    }

    nonisolated private static func isPinyinCharacter(_ character: Character) -> Bool {
        character.isLetter || character == ":"
    }

    nonisolated private static func toneVowelIndex(in characters: [Character]) -> Int? {
        if let index = characters.firstIndex(where: { $0 == "a" || $0 == "A" }) {
            return index
        }

        if let index = characters.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            return index
        }

        for index in characters.indices.dropLast()
        where (characters[index] == "o" || characters[index] == "O")
            && (characters[index + 1] == "u" || characters[index + 1] == "U") {
            return index
        }

        return characters.lastIndex(where: isToneVowel)
    }

    nonisolated private static func isToneVowel(_ character: Character) -> Bool {
        "aeiouüAEIOUÜ".contains(character)
    }

    nonisolated private static func toneMarkedVowel(
        _ vowel: Character,
        tone: Int
    ) -> Character? {
        let toneIndex = tone - 1
        let toneMarks: [Character: [Character]] = [
            "a": ["ā", "á", "ǎ", "à"],
            "e": ["ē", "é", "ě", "è"],
            "i": ["ī", "í", "ǐ", "ì"],
            "o": ["ō", "ó", "ǒ", "ò"],
            "u": ["ū", "ú", "ǔ", "ù"],
            "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
            "A": ["Ā", "Á", "Ǎ", "À"],
            "E": ["Ē", "É", "Ě", "È"],
            "I": ["Ī", "Í", "Ǐ", "Ì"],
            "O": ["Ō", "Ó", "Ǒ", "Ò"],
            "U": ["Ū", "Ú", "Ǔ", "Ù"],
            "Ü": ["Ǖ", "Ǘ", "Ǚ", "Ǜ"],
        ]
        return toneMarks[vowel]?[toneIndex]
    }
}
