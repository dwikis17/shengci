import Foundation

struct PremiumAccess {
    let isPremium: Bool

    func allowsHSKLevel(_ level: Int) -> Bool {
        isPremium || level <= 1
    }

    func allowsScanResult(hasUsedFreeResult: Bool) -> Bool {
        isPremium || !hasUsedFreeResult
    }

    func allowsPractice(
        lastFreePracticeAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        isPremium
            || lastFreePracticeAt.map {
                !calendar.isDate($0, inSameDayAs: now)
            } ?? true
    }
}
