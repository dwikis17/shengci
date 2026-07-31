import Foundation
import SwiftData

@Model
final class LearningSyncState {
    var hskLevel: Int = 1
    var positionIndex: Int = 0
    var positionUpdatedAt: Date = Date.distantPast
    var practiceResetAt: Date = Date.distantPast

    init(
        hskLevel: Int,
        positionIndex: Int = 0,
        positionUpdatedAt: Date = .distantPast,
        practiceResetAt: Date = .distantPast
    ) {
        self.hskLevel = hskLevel
        self.positionIndex = positionIndex
        self.positionUpdatedAt = positionUpdatedAt
        self.practiceResetAt = practiceResetAt
    }
}
