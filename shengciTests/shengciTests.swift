//
//  shengciTests.swift
//  shengciTests
//
//  Created by Dwiki on 27/07/26.
//

import Testing
import SwiftData
import UserNotifications
@testable import shengci

@MainActor
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

    @Test func freePracticeResetsOnTheNextLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Jakarta"))
        let firstPractice = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 7,
                day: 31,
                hour: 9
            ))
        )
        let laterToday = try #require(
            calendar.date(byAdding: .hour, value: 2, to: firstPractice)
        )
        let tomorrow = try #require(
            calendar.date(byAdding: .day, value: 1, to: firstPractice)
        )
        let free = PremiumAccess(isPremium: false)
        let premium = PremiumAccess(isPremium: true)

        #expect(free.allowsPractice(
            lastFreePracticeAt: nil,
            now: firstPractice,
            calendar: calendar
        ))
        #expect(!free.allowsPractice(
            lastFreePracticeAt: firstPractice,
            now: laterToday,
            calendar: calendar
        ))
        #expect(free.allowsPractice(
            lastFreePracticeAt: firstPractice,
            now: tomorrow,
            calendar: calendar
        ))
        #expect(premium.allowsPractice(
            lastFreePracticeAt: firstPractice,
            now: laterToday,
            calendar: calendar
        ))
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

    @Test func explainsPartOfSpeechCodes() {
        #expect(PartOfSpeechFormatter.displayName(for: "v") == "Verb")
        #expect(PartOfSpeechFormatter.displayName(for: "vn") == "Nominal verb")
        #expect(PartOfSpeechFormatter.displayName(for: "unknown") == "UNKNOWN")
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

    @Test func newestSavedWordActionWinsReconciliation() throws {
        let container = try syncContainer()
        let context = container.mainContext
        let olderSave = SavedWord(
            simplified: "好",
            pinyin: "hao3",
            savedAt: Date(timeIntervalSince1970: 100)
        )
        let newerRemoval = SavedWord(
            simplified: "好",
            pinyin: "hao3",
            savedAt: Date(timeIntervalSince1970: 100)
        )
        newerRemoval.remove(at: Date(timeIntervalSince1970: 200))
        context.insert(olderSave)
        context.insert(newerRemoval)

        try LearningDataSync.reconcile(in: context)

        let records = try context.fetch(FetchDescriptor<SavedWord>())
        #expect(records.count == 1)
        #expect(records.first?.isSaved == false)
    }

    @Test func progressAndResetTimestampsMergeIndependently() throws {
        let container = try syncContainer()
        let context = container.mainContext
        let newerPosition = LearningSyncState(
            hskLevel: 2,
            positionIndex: 42,
            positionUpdatedAt: Date(timeIntervalSince1970: 300),
            practiceResetAt: Date(timeIntervalSince1970: 100)
        )
        let newerReset = LearningSyncState(
            hskLevel: 2,
            positionIndex: 3,
            positionUpdatedAt: Date(timeIntervalSince1970: 200),
            practiceResetAt: Date(timeIntervalSince1970: 400)
        )
        context.insert(newerPosition)
        context.insert(newerReset)

        try LearningDataSync.reconcile(in: context)

        let states = try context.fetch(FetchDescriptor<LearningSyncState>())
        let state = try #require(states.first)
        #expect(states.count == 1)
        #expect(state.positionIndex == 42)
        #expect(state.practiceResetAt == Date(timeIntervalSince1970: 400))
    }

    @Test func resetHidesSessionsThatArriveLater() {
        let beforeReset = PracticeSessionRecord(
            hskLevel: 1,
            date: Date(timeIntervalSince1970: 100),
            score: 1,
            totalQuestions: 1,
            items: []
        )
        let afterReset = PracticeSessionRecord(
            hskLevel: 1,
            date: Date(timeIntervalSince1970: 300),
            score: 1,
            totalQuestions: 1,
            items: []
        )
        let state = LearningSyncState(
            hskLevel: 1,
            practiceResetAt: Date(timeIntervalSince1970: 200)
        )

        let visible = LearningDataSync.visibleSessions(
            [beforeReset, afterReset],
            states: [state],
            level: 1
        )

        #expect(visible.map(\.id) == [afterReset.id])
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

    private func syncContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SavedWord.self,
            PracticeSessionRecord.self,
            LearningSyncState.self,
            configurations: configuration
        )
    }
}
