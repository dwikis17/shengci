//
//  shengciTests.swift
//  shengciTests
//
//  Created by Dwiki on 27/07/26.
//

import Testing
import UserNotifications
@testable import shengci

struct shengciTests {
    @Test func premiumAccessPolicy() {
        let free = PremiumAccess(isPremium: false)
        let premium = PremiumAccess(isPremium: true)

        #expect(free.allowsHSKLevel(1))
        #expect(free.allowsHSKLevel(2))
        #expect(!free.allowsHSKLevel(3))
        #expect(free.allowsScanResult(hasUsedFreeResult: false))
        #expect(!free.allowsScanResult(hasUsedFreeResult: true))
        #expect(premium.allowsHSKLevel(7))
        #expect(premium.allowsScanResult(hasUsedFreeResult: true))
    }

    @Test func quizUsesUniqueEligibleWordsAndLimitsSessionLength() {
        let words = (0..<12).map { word("字\($0)", meanings: ["meaning \($0)"]) }
            + [word("empty", meanings: [])]

        let questions = PracticeQuiz.makeQuestions(from: words)

        #expect(questions.count == 10)
        #expect(Set(questions.map(\.word.simplified)).count == questions.count)
        #expect(!questions.contains { $0.word.simplified == "empty" })
    }

    @Test func acceptsEveryPrimaryMeaningAsCorrect() {
        let target = word("好", meanings: ["good", "well"])
        let question = PracticeQuestion(word: target, choices: ["good"])

        #expect(question.isCorrect("good"))
        #expect(question.isCorrect("well"))
        #expect(!question.isCorrect("bad"))
    }

    @Test func choicesUseSameLevelWordsAndStaySafeWhenUndersized() {
        let target = word("你", meanings: ["you"])
        let peer = word("我", meanings: ["I"])
        let choices = PracticeQuiz.choices(for: target, from: [target, peer])

        #expect(choices.contains("you"))
        #expect(Set(choices).isSubset(of: Set(["you", "I"])))
        #expect(choices.count == 2)
        #expect(PracticeQuiz.makeQuestions(from: []).isEmpty)
    }

    @Test func schedulesSixtyDailyWordsFromTheNextNineAM() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 7,
                day: 31,
                hour: 8
            ))
        )

        let requests = DailyWordNotificationManager.makeRequests(
            from: now,
            calendar: calendar
        )

        #expect(requests.count == 60)
        #expect(Set(requests.map(\.identifier)).count == 60)

        let trigger = try #require(
            requests.first?.trigger as? UNCalendarNotificationTrigger
        )
        #expect(trigger.dateComponents.hour == 9)
        #expect(trigger.dateComponents.day == 31)

        let delivery = try #require(calendar.date(from: trigger.dateComponents))
        let word = WordOfTheDayManager.shared.getWord(for: delivery)
        #expect(requests.first?.content.title == word.simplified)
        #expect(requests.first?.content.body.hasPrefix(word.formattedPinyin) == true)
    }

    private func word(_ simplified: String, meanings: [String]) -> WordModel {
        WordModel(
            simplified: simplified,
            radical: "",
            frequency: 0,
            pos: [],
            forms: [
                WordForm(
                    traditional: simplified,
                    transcriptions: WordTranscription(
                        pinyin: "pinyin",
                        numeric: "",
                        wadegiles: "",
                        bopomofo: "",
                        romatzyh: ""
                    ),
                    meanings: meanings,
                    classifiers: []
                )
            ]
        )
    }
}
