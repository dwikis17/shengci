import CoreGraphics
import Testing
@testable import shengci

struct StrokeOrderStrokeValidatorTests {
    @Test func acceptsAGestureThatFollowsTheMedian() {
        let median = [
            StrokeOrderPoint(x: 128, y: 512),
            StrokeOrderPoint(x: 512, y: 512),
            StrokeOrderPoint(x: 896, y: 512),
        ]

        let result = StrokeOrderStrokeValidator().validate(
            points: [
                CGPoint(x: 25, y: 100),
                CGPoint(x: 100, y: 100),
                CGPoint(x: 175, y: 100),
            ],
            for: makeStroke(median: median),
            in: CGRect(x: 0, y: 0, width: 200, height: 200)
        )

        #expect(result == .accepted)
    }

    @Test func rejectsAGestureThatStartsAwayFromTheMedianStart() {
        let result = StrokeOrderStrokeValidator().validate(
            points: [
                CGPoint(x: 175, y: 100),
                CGPoint(x: 125, y: 100),
                CGPoint(x: 75, y: 100),
            ],
            for: makeStroke(),
            in: CGRect(x: 0, y: 0, width: 200, height: 200)
        )

        #expect(result == .rejected(.startPoint))
    }

    @Test func rejectsAReversedGestureAfterStartingNearTheDot() {
        let result = StrokeOrderStrokeValidator().validate(
            points: [
                CGPoint(x: 25, y: 100),
                CGPoint(x: 15, y: 100),
                CGPoint(x: 5, y: 100),
            ],
            for: makeStroke(),
            in: CGRect(x: 0, y: 0, width: 200, height: 200)
        )

        #expect(result == .rejected(.direction))
    }

    @Test func rejectsATapThatDoesNotTraceTheStroke() {
        let result = StrokeOrderStrokeValidator().validate(
            points: [CGPoint(x: 25, y: 100), CGPoint(x: 27, y: 100)],
            for: makeStroke(),
            in: CGRect(x: 0, y: 0, width: 200, height: 200)
        )

        #expect(result == .rejected(.tooShort))
    }

    @Test func acceptsNaturalVariationInsideTheForgivingCorridor() {
        let result = StrokeOrderStrokeValidator().validate(
            points: [
                CGPoint(x: 25, y: 100),
                CGPoint(x: 100, y: 126),
                CGPoint(x: 175, y: 100),
            ],
            for: makeStroke(),
            in: CGRect(x: 0, y: 0, width: 200, height: 200)
        )

        #expect(result == .accepted)
    }

    @Test func normalizesGestureCoordinatesInsideANonSquareCanvas() {
        let rect = CGRect(x: 10, y: 20, width: 200, height: 100)
        let result = StrokeOrderStrokeValidator().validate(
            points: [
                CGPoint(x: 85, y: 45),
                CGPoint(x: 110, y: 45),
                CGPoint(x: 135, y: 45),
            ],
            for: makeStroke(),
            in: rect
        )

        #expect(result == .accepted)
    }

    @Test func repeatedInvalidGesturesRemainRetryable() {
        let validator = StrokeOrderStrokeValidator()
        let gesture = [
            CGPoint(x: 25, y: 100),
            CGPoint(x: 15, y: 100),
            CGPoint(x: 5, y: 100),
        ]
        let stroke = makeStroke()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)

        #expect(validator.validate(points: gesture, for: stroke, in: rect) == .rejected(.direction))
        #expect(validator.validate(points: gesture, for: stroke, in: rect) == .rejected(.direction))
    }

    private func makeStroke(
        median: [StrokeOrderPoint] = [
            StrokeOrderPoint(x: 128, y: 512),
            StrokeOrderPoint(x: 512, y: 512),
            StrokeOrderPoint(x: 896, y: 512),
        ]
    ) -> StrokeOrderStroke {
        StrokeOrderStroke(
            commands: [.move(median[0]), .line(median[1]), .line(median[2]), .close],
            median: median
        )
    }
}
