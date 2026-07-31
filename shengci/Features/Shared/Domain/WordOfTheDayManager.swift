//
//  WordOfTheDayManager.swift
//  shengci
//
//  Created by Dwiki on 28/07/26.
//

import Foundation

public struct WordOfTheDay: Codable, Identifiable, Sendable {
    public var id: String { simplified }
    public let simplified: String
    public let traditional: String
    public let pinyin: String
    public let formattedPinyin: String
    public let meanings: [String]
    public let radical: String
    public let hskLevel: Int
    public let pos: [String]

    public nonisolated init(
        simplified: String,
        traditional: String = "",
        pinyin: String,
        formattedPinyin: String,
        meanings: [String],
        radical: String,
        hskLevel: Int,
        pos: [String] = []
    ) {
        self.simplified = simplified
        self.traditional = traditional
        self.pinyin = pinyin
        self.formattedPinyin = formattedPinyin
        self.meanings = meanings
        self.radical = radical
        self.hskLevel = hskLevel
        self.pos = pos
    }
}

public final class WordOfTheDayManager: Sendable {
    public nonisolated static let shared = WordOfTheDayManager()

    private nonisolated init() {}

    /// Returns the Word of the Day deterministically based on the given Date.
    public nonisolated func getWord(for date: Date = Date()) -> WordOfTheDay {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        
        // Compute a deterministic seed for the day
        let dateSeed = year * 1000 + dayOfYear
        
        // HSK levels 1 through 6
        let targetLevel = ((dateSeed * 7 + 13) % 6) + 1
        
        if let word = loadWordFromHSK(level: targetLevel, seed: dateSeed) {
            return word
        }
        
        // Fallback search across levels if target level failed
        for fallbackLevel in 1...6 {
            if let word = loadWordFromHSK(level: fallbackLevel, seed: dateSeed) {
                return word
            }
        }

        // Ultimate fallback
        return WordOfTheDay(
            simplified: "你好",
            traditional: "你好",
            pinyin: "ni3 hao3",
            formattedPinyin: "Nǐ hǎo",
            meanings: ["Hello", "Hi"],
            radical: "亻",
            hskLevel: 1,
            pos: ["expression"]
        )
    }

    private nonisolated func loadWordFromHSK(level: Int, seed: Int) -> WordOfTheDay? {
        let fileName = "hsk\(level)"
        guard let url = findJSONURL(fileName: fileName),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordModel].self, from: data),
              !words.isEmpty
        else {
            return nil
        }

        let index = abs(seed * 31 + level * 17) % words.count
        let wordModel = words[index]
        let form = wordModel.forms.first

        let rawPinyin = form?.transcriptions.pinyin ?? ""
        let formattedPinyin = PinyinFormatter.display(rawPinyin)
        let traditional = form?.traditional ?? wordModel.simplified
        let meanings = form?.meanings ?? []

        return WordOfTheDay(
            simplified: wordModel.simplified,
            traditional: traditional,
            pinyin: rawPinyin,
            formattedPinyin: formattedPinyin,
            meanings: meanings,
            radical: wordModel.radical,
            hskLevel: level,
            pos: wordModel.pos
        )
    }

    private nonisolated func findJSONURL(fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            return url
        }
        
        // Also check frameworks / extension bundles if running inside widget target
        let bundle = Bundle(for: WordOfTheDayManager.self)
        if let url = bundle.url(forResource: fileName, withExtension: "json") {
            return url
        }

        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            if let target = urls.first(where: { $0.lastPathComponent == "\(fileName).json" }) {
                return target
            }
        }

        return nil
    }
}
