import CoreGraphics

struct StrokeOrderStrokeValidator {
    enum Failure: Equatable, Sendable {
        case startPoint
        case direction
        case tooShort
        case corridor
        case progress

        var coachingMessage: String {
            switch self {
            case .startPoint:
                "Start at the highlighted dot."
            case .direction:
                "Follow the stroke direction."
            case .tooShort:
                "Trace the full stroke."
            case .corridor:
                "Keep your stroke near the guide."
            case .progress:
                "Follow the guide to the end."
            }
        }
    }

    enum Result: Equatable, Sendable {
        case accepted
        case rejected(Failure)
    }

    // ponytail: fixed forgiving thresholds keep the tutor predictable; tune from user testing before adding adaptive scoring.
    private let startTolerance: CGFloat = 205
    private let corridorTolerance: CGFloat = 184
    private let minimumCorridorCoverage: CGFloat = 0.65
    private let minimumDirectionRatio: CGFloat = 0.60
    private let minimumProgress: CGFloat = 0.55
    private let minimumGestureLength: CGFloat = 52

    func validate(
        points: [CGPoint],
        for stroke: StrokeOrderStroke,
        in rect: CGRect
    ) -> Result {
        guard rect.width > 0, rect.height > 0,
            points.count >= 2,
            stroke.median.count >= 2
        else {
            return .rejected(.tooShort)
        }

        let gesture = points.map { normalizedPoint($0, in: rect) }
        let median = stroke.median.map { CGPoint(x: $0.x, y: $0.y) }
        let medianLength = polylineLength(median)

        guard medianLength > 0 else {
            return .rejected(.tooShort)
        }

        guard polylineLength(gesture) >= minimumGestureLength else {
            return .rejected(.tooShort)
        }

        guard distance(gesture[0], median[0]) <= startTolerance else {
            return .rejected(.startPoint)
        }

        let projections = gesture.map { project($0, onto: median) }
        let corridorCoverage = CGFloat(
            projections.filter { $0.distance <= corridorTolerance }.count
        ) / CGFloat(projections.count)
        guard corridorCoverage >= minimumCorridorCoverage else {
            return .rejected(.corridor)
        }

        var forwardDistance: CGFloat = 0
        var backwardDistance: CGFloat = 0
        for pair in zip(projections, projections.dropFirst()) {
            let delta = pair.1.progress - pair.0.progress
            if delta >= 0 {
                forwardDistance += delta
            } else {
                backwardDistance -= delta
            }
        }

        let totalProgressMovement = forwardDistance + backwardDistance
        let directionRatio = totalProgressMovement > 0
            ? forwardDistance / totalProgressMovement
            : 0
        guard directionRatio >= minimumDirectionRatio else {
            return .rejected(.direction)
        }

        guard let finalProgress = projections.last?.progress,
            finalProgress / medianLength >= minimumProgress
        else {
            return .rejected(.progress)
        }

        return .accepted
    }

    private struct Projection {
        let progress: CGFloat
        let distance: CGFloat
    }

    private func normalizedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        let scale = min(rect.width, rect.height) / 1_024
        let origin = CGPoint(
            x: rect.midX - 512 * scale,
            y: rect.midY - 512 * scale
        )
        return CGPoint(
            x: (point.x - origin.x) / scale,
            y: (point.y - origin.y) / scale
        )
    }

    private func project(_ point: CGPoint, onto polyline: [CGPoint]) -> Projection {
        var best = Projection(progress: 0, distance: .greatestFiniteMagnitude)
        var progress: CGFloat = 0

        for pair in zip(polyline, polyline.dropFirst()) {
            let start = pair.0
            let end = pair.1
            let segment = CGPoint(x: end.x - start.x, y: end.y - start.y)
            let segmentLengthSquared = segment.x * segment.x + segment.y * segment.y
            let segmentLength = segmentLengthSquared.squareRoot()

            if segmentLengthSquared == 0 {
                continue
            }

            let relative = CGPoint(x: point.x - start.x, y: point.y - start.y)
            let rawPosition =
                (relative.x * segment.x + relative.y * segment.y)
                / segmentLengthSquared
            let position = min(max(rawPosition, 0), 1)
            let projected = CGPoint(
                x: start.x + segment.x * position,
                y: start.y + segment.y * position
            )
            let candidate = Projection(
                progress: progress + segmentLength * position,
                distance: distance(point, projected)
            )

            if candidate.distance < best.distance {
                best = candidate
            }
            progress += segmentLength
        }

        return best
    }

    private func polylineLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst())
            .map { distance($0.0, $0.1) }
            .reduce(0, +)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let x = lhs.x - rhs.x
        let y = lhs.y - rhs.y
        return (x * x + y * y).squareRoot()
    }
}
