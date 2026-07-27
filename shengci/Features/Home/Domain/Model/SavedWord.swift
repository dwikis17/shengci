//
//  SavedWord.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import Foundation
import SwiftData

@Model
final class SavedWord {
    @Attribute(.unique) var simplified: String
    var pinyin: String
    var traditional: String
    var meaningsData: String
    var radical: String
    var frequency: Int
    var posData: String
    var savedAt: Date
    
    init(
        simplified: String,
        pinyin: String,
        traditional: String = "",
        meanings: [String] = [],
        radical: String = "",
        frequency: Int = 0,
        pos: [String] = [],
        savedAt: Date = Date()
    ) {
        self.simplified = simplified
        self.pinyin = pinyin
        self.traditional = traditional
        self.meaningsData = meanings.joined(separator: "||")
        self.radical = radical
        self.frequency = frequency
        self.posData = pos.joined(separator: ",")
        self.savedAt = savedAt
    }
    
    convenience init(from word: WordModel) {
        let primaryForm = word.forms.first
        self.init(
            simplified: word.simplified,
            pinyin: primaryForm?.transcriptions.pinyin ?? "",
            traditional: primaryForm?.traditional ?? word.simplified,
            meanings: primaryForm?.meanings ?? [],
            radical: word.radical,
            frequency: word.frequency,
            pos: word.pos,
            savedAt: Date()
        )
    }
    
    var meanings: [String] {
        meaningsData.isEmpty ? [] : meaningsData.components(separatedBy: "||")
    }
    
    var pos: [String] {
        posData.isEmpty ? [] : posData.components(separatedBy: ",")
    }
}
