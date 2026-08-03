import CoreGraphics
import Foundation

struct StrokeOrderPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        guard container.count == 2 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Stroke-order point must contain x and y"
            )
        }
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }

    func cgPoint(in rect: CGRect) -> CGPoint {
        let scale = min(rect.width, rect.height) / 1_024
        let origin = CGPoint(
            x: rect.midX - 512 * scale,
            y: rect.midY - 512 * scale
        )
        return CGPoint(
            x: origin.x + x * scale,
            y: origin.y + y * scale
        )
    }
}

struct StrokePathCommand: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case move = "M"
        case line = "L"
        case quad = "Q"
        case cubic = "C"
        case close = "Z"

        var pointCount: Int {
            switch self {
            case .move, .line: 1
            case .quad: 2
            case .cubic: 3
            case .close: 0
            }
        }
    }

    let kind: Kind
    let points: [StrokeOrderPoint]

    init(kind: Kind, points: [StrokeOrderPoint] = []) {
        self.kind = kind
        self.points = points
    }

    static func move(_ point: StrokeOrderPoint) -> Self {
        Self(kind: .move, points: [point])
    }

    static func line(_ point: StrokeOrderPoint) -> Self {
        Self(kind: .line, points: [point])
    }

    static func quad(control: StrokeOrderPoint, end: StrokeOrderPoint) -> Self {
        Self(kind: .quad, points: [control, end])
    }

    static func cubic(
        control1: StrokeOrderPoint,
        control2: StrokeOrderPoint,
        end: StrokeOrderPoint
    ) -> Self {
        Self(kind: .cubic, points: [control1, control2, end])
    }

    static var close: Self {
        Self(kind: .close)
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawKind = try container.decode(String.self)
        guard let kind = Kind(rawValue: rawKind) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown stroke path command: \(rawKind)"
            )
        }

        var points: [StrokeOrderPoint] = []
        for _ in 0..<kind.pointCount {
            points.append(
                StrokeOrderPoint(
                    x: try container.decode(Double.self),
                    y: try container.decode(Double.self)
                )
            )
        }

        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Too many coordinates for stroke path command"
            )
        }
        self.init(kind: kind, points: points)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(kind.rawValue)
        for point in points {
            try container.encode(point.x)
            try container.encode(point.y)
        }
    }

    func append(to path: CGMutablePath, in rect: CGRect) {
        switch kind {
        case .move:
            guard let point = points.first else { return }
            path.move(to: point.cgPoint(in: rect))
        case .line:
            guard let point = points.first else { return }
            path.addLine(to: point.cgPoint(in: rect))
        case .quad:
            guard points.count == 2 else { return }
            path.addQuadCurve(
                to: points[1].cgPoint(in: rect),
                control: points[0].cgPoint(in: rect)
            )
        case .cubic:
            guard points.count == 3 else { return }
            path.addCurve(
                to: points[2].cgPoint(in: rect),
                control1: points[0].cgPoint(in: rect),
                control2: points[1].cgPoint(in: rect)
            )
        case .close:
            path.closeSubpath()
        }
    }
}

struct StrokeOrderStroke: Codable, Equatable, Sendable {
    let commands: [StrokePathCommand]
    let median: [StrokeOrderPoint]

    enum CodingKeys: String, CodingKey {
        case commands = "path"
        case median
    }

    func cgPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        commands.forEach { $0.append(to: path, in: rect) }
        return path
    }

    func medianPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard let first = median.first else { return path }
        path.move(to: first.cgPoint(in: rect))
        for point in median.dropFirst() {
            path.addLine(to: point.cgPoint(in: rect))
        }
        return path
    }
}

struct StrokeOrderCharacter: Codable, Equatable, Sendable {
    let character: String
    let strokes: [StrokeOrderStroke]
}

struct StrokeOrderDataStore {
    enum StoreError: LocalizedError {
        case resourceMissing
        case invalidCharacterKey(String)
        case invalidCharacterData(String)

        var errorDescription: String? {
            switch self {
            case .resourceMissing:
                "The stroke-order resource is missing."
            case .invalidCharacterKey(let key):
                "The stroke-order resource contains an invalid character key: \(key)."
            case .invalidCharacterData(let character):
                "The stroke-order resource contains invalid data for \(character)."
            }
        }
    }

    private let characters: [String: StrokeOrderCharacter]

    static let empty = StrokeOrderDataStore(characters: [:])
    static let bundled = (try? StrokeOrderDataStore()) ?? .empty

    private init(characters: [String: StrokeOrderCharacter]) {
        self.characters = characters
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode(
            [String: StrokeOrderCharacter].self,
            from: data
        )

        for (key, value) in decoded {
            guard key.count == 1 else {
                throw StoreError.invalidCharacterKey(key)
            }
            guard key == value.character, !value.strokes.isEmpty,
                value.strokes.allSatisfy({ !$0.commands.isEmpty && $0.median.count >= 2 })
            else {
                throw StoreError.invalidCharacterData(key)
            }
        }
        characters = decoded
    }

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "stroke-order", withExtension: "json") else {
            throw StoreError.resourceMissing
        }
        try self.init(data: Data(contentsOf: url))
    }

    func character(for value: String) -> StrokeOrderCharacter? {
        characters[value]
    }

    var count: Int {
        characters.count
    }
}
