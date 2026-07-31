//
//  WordModel.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import Foundation

public struct WordModel: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public let simplified: String
    public let radical: String
    public let frequency: Int
    public let pos: [String]
    public let forms: [WordForm]
    
    enum CodingKeys: String, CodingKey {
        case simplified
        case radical
        case frequency
        case pos
        case forms
    }
}

public struct WordForm: Codable, Hashable, Sendable {
    public let traditional: String
    public let transcriptions: WordTranscription
    public let meanings: [String]
    public let classifiers: [String]
}

public struct WordTranscription: Codable, Hashable, Sendable {
    public let pinyin: String
    public let numeric: String
    public let wadegiles: String
    public let bopomofo: String
    public let romatzyh: String
}

public typealias Word = WordModel

enum PartOfSpeechFormatter {
    private static let names = [
        "a": "Adjective",
        "ad": "Adverbial adjective",
        "an": "Nominal adjective",
        "b": "Attributive word",
        "c": "Conjunction",
        "cc": "Coordinating conjunction",
        "d": "Adverb",
        "e": "Interjection",
        "f": "Locality word",
        "g": "Morpheme",
        "h": "Prefix",
        "k": "Suffix",
        "l": "Idiom",
        "m": "Numeral",
        "mg": "Numeral morpheme",
        "mq": "Numeral–classifier",
        "n": "Noun",
        "nr": "Person name",
        "ns": "Place name",
        "nt": "Organization",
        "nz": "Proper noun",
        "o": "Onomatopoeia",
        "p": "Preposition",
        "q": "Classifier",
        "qt": "Time classifier",
        "qv": "Verbal classifier",
        "r": "Pronoun",
        "rg": "Pronoun morpheme",
        "s": "Location word",
        "t": "Time word",
        "tg": "Time morpheme",
        "u": "Particle",
        "v": "Verb",
        "vn": "Nominal verb",
        "y": "Modal particle",
        "z": "State word",
    ]

    static func displayName(for code: String) -> String {
        names[code.lowercased()] ?? code.uppercased()
    }
}
