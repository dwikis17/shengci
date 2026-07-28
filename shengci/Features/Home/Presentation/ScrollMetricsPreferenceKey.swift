import SwiftUI

struct ScrollMetrics: Equatable {
    let minimumY: Double
    let contentHeight: Double

    static let zero = ScrollMetrics(minimumY: 0, contentHeight: 0)
}

struct ScrollMetricsPreferenceKey: PreferenceKey {
    static let defaultValue = ScrollMetrics.zero

    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) {
        value = nextValue()
    }
}
