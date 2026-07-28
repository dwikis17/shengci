import Foundation
import UIKit
import Vision

@MainActor
final class ChineseHandwritingRecognizer {
    static let shared = ChineseHandwritingRecognizer()

    func recognize(image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var candidates: [String] = []
                var seen = Set<String>()

                for observation in observations {
                    let topCandidates = observation.topCandidates(5)
                    for recognized in topCandidates {
                        for char in recognized.string {
                            let str = String(char)
                            // Keep Chinese character candidates
                            if char.isTraditionalOrSimplifiedChinese, seen.insert(str).inserted {
                                candidates.append(str)
                            }
                        }
                    }
                }

                continuation.resume(returning: candidates)
            }

            request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

extension Character {
    var isTraditionalOrSimplifiedChinese: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}
