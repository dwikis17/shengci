import Foundation
import MLKitDigitalInkRecognition

struct HandwritingPoint: Sendable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let timestampMilliseconds: Int
}

typealias HandwritingStroke = [HandwritingPoint]

protocol ChineseHandwritingRecognizing: AnyObject {
    func prepare() async throws
    func recognize(strokes: [HandwritingStroke], writingArea: CGSize) async throws -> [String]
}

enum ChineseHandwritingRecognizerError: LocalizedError {
    case unavailableModel
    case modelNotDownloaded
    case downloadTimedOut
    case noRecognitionResult

    var errorDescription: String? {
        switch self {
        case .unavailableModel:
            "Chinese handwriting recognition is unavailable on this device."
        case .modelNotDownloaded:
            "The Chinese handwriting model is still downloading."
        case .downloadTimedOut:
            "The Chinese handwriting model could not be downloaded. Please try again."
        case .noRecognitionResult:
            "No handwriting candidates were recognized."
        }
    }
}

@MainActor
final class ChineseHandwritingRecognizer: ChineseHandwritingRecognizing {
    static let shared = ChineseHandwritingRecognizer()

    private let modelManager = ModelManager.modelManager()
    private let model: DigitalInkRecognitionModel?
    private let recognizer: DigitalInkRecognizer?

    private init() {
        let model = DigitalInkRecognitionModel(modelIdentifier: .zhHaniCn)
        self.model = model
        recognizer = DigitalInkRecognizer.digitalInkRecognizer(
            options: DigitalInkRecognizerOptions(model: model)
        )
    }

    func prepare() async throws {
        guard let model else { throw ChineseHandwritingRecognizerError.unavailableModel }
        guard !modelManager.isModelDownloaded(model) else { return }

        let conditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: true
        )

        _ = modelManager.download(model, conditions: conditions)
        for _ in 0..<480 {
            try Task.checkCancellation()
            if modelManager.isModelDownloaded(model) {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw ChineseHandwritingRecognizerError.downloadTimedOut
    }

    func recognize(strokes: [HandwritingStroke], writingArea: CGSize) async throws -> [String] {
        guard let model, let recognizer else {
            throw ChineseHandwritingRecognizerError.unavailableModel
        }
        guard modelManager.isModelDownloaded(model) else {
            throw ChineseHandwritingRecognizerError.modelNotDownloaded
        }

        let ink = Ink(
            strokes: strokes.map { stroke in
                Stroke(
                    points: stroke.map {
                        StrokePoint(
                            x: Float($0.x),
                            y: Float($0.y),
                            t: $0.timestampMilliseconds
                        )
                    }
                )
            }
        )
        let context = DigitalInkRecognitionContext(
            preContext: "",
            writingArea: WritingArea(width: Float(writingArea.width), height: Float(writingArea.height))
        )

        let candidates: [String] = try await withCheckedThrowingContinuation { continuation in
            recognizer.recognize(ink: ink, context: context) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result.candidates.map(\.text))
                } else {
                    continuation.resume(throwing: ChineseHandwritingRecognizerError.noRecognitionResult)
                }
            }
        }

        return HandwritingCandidateFilter.singleHanzi(from: candidates)
    }
}

enum HandwritingCandidateFilter {
    static func singleHanzi(from candidates: [String], limit: Int = 5) -> [String] {
        var seen = Set<String>()

        return candidates.compactMap { candidate in
            guard candidate.count == 1, let character = candidate.first, character.isChineseHanzi else {
                return nil
            }
            return candidate
        }
        .filter { seen.insert($0).inserted }
        .prefix(limit)
        .map { $0 }
    }
}

extension Character {
    var isChineseHanzi: Bool {
        unicodeScalars.allSatisfy { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0x20000...0x2A6DF).contains(scalar.value)
        }
    }
}
