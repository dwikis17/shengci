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
