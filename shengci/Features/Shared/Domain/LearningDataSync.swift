import Foundation
import SwiftData

@MainActor
enum LearningDataSync {
    static func reconcile(in context: ModelContext) throws {
        try reconcileSavedWords(in: context)
        try reconcileSessions(in: context)
        try reconcileStates(in: context)
        try migrateLocalPositions(in: context)
        if context.hasChanges {
            try context.save()
        }
    }

    static func state(for level: Int, in context: ModelContext) throws -> LearningSyncState {
        let states = try context.fetch(FetchDescriptor<LearningSyncState>())
            .filter { $0.hskLevel == level }
        if let state = states.max(by: { $0.positionUpdatedAt < $1.positionUpdatedAt }) {
            return state
        }
        let state = LearningSyncState(hskLevel: level)
        context.insert(state)
        return state
    }

    static func resetPractice(level: Int, sessions: [PracticeSessionRecord], in context: ModelContext) throws {
        let now = Date()
        for session in sessions where session.hskLevel == level && !session.isDeleted {
            session.remove(at: now)
        }
        let progress = try state(for: level, in: context)
        progress.practiceResetAt = now
        try context.save()
    }

    static func visibleSessions(
        _ sessions: [PracticeSessionRecord],
        states: [LearningSyncState],
        level: Int? = nil
    ) -> [PracticeSessionRecord] {
        let resetByLevel = Dictionary(
            states.map { ($0.hskLevel, $0.practiceResetAt) },
            uniquingKeysWith: max
        )
        return sessions.filter {
            !$0.isDeleted
                && (level == nil || $0.hskLevel == level)
                && $0.date > resetByLevel[$0.hskLevel, default: .distantPast]
        }
    }

    private static func reconcileSavedWords(in context: ModelContext) throws {
        let words = try context.fetch(FetchDescriptor<SavedWord>())
        for records in Dictionary(grouping: words, by: \.simplified).values {
            for record in records where record.modifiedAt == .distantPast {
                record.modifiedAt = record.savedAt
            }
            guard records.count > 1,
                  let winner = records.max(by: { actionDate($0) < actionDate($1) })
            else { continue }
            for record in records where record !== winner {
                context.delete(record)
            }
        }
    }

    private static func reconcileSessions(in context: ModelContext) throws {
        let sessions = try context.fetch(FetchDescriptor<PracticeSessionRecord>())
        for records in Dictionary(grouping: sessions, by: \.id).values {
            for record in records where record.modifiedAt == .distantPast {
                record.modifiedAt = record.date
            }
            guard records.count > 1,
                  let winner = records.max(by: { $0.modifiedAt < $1.modifiedAt })
            else { continue }
            for record in records where record !== winner {
                context.delete(record)
            }
        }
    }

    private static func reconcileStates(in context: ModelContext) throws {
        let states = try context.fetch(FetchDescriptor<LearningSyncState>())
        for records in Dictionary(grouping: states, by: \.hskLevel).values where records.count > 1 {
            guard let winner = records.max(by: { $0.positionUpdatedAt < $1.positionUpdatedAt })
            else { continue }
            if let latestPosition = records.max(by: { $0.positionUpdatedAt < $1.positionUpdatedAt }) {
                winner.positionIndex = latestPosition.positionIndex
                winner.positionUpdatedAt = latestPosition.positionUpdatedAt
            }
            winner.practiceResetAt = records.map(\.practiceResetAt).max() ?? .distantPast
            for record in records where record !== winner {
                context.delete(record)
            }
        }
    }

    private static func migrateLocalPositions(in context: ModelContext) throws {
        let defaults = UserDefaults.standard
        for level in 1...7 {
            let key = "hsk_progress_\(level)"
            let migrationKey = "\(key)_icloud_migrated"
            guard !defaults.bool(forKey: migrationKey),
                  defaults.object(forKey: key) != nil
            else { continue }
            let state = try state(for: level, in: context)
            if state.positionUpdatedAt == .distantPast {
                state.positionIndex = defaults.integer(forKey: key)
                state.positionUpdatedAt = Date()
            }
            defaults.set(true, forKey: migrationKey)
        }
    }

    private static func actionDate(_ word: SavedWord) -> Date {
        max(word.modifiedAt, word.savedAt)
    }
}
