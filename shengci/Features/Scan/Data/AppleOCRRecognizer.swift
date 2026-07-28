import Foundation
import ImageIO
import Vision

actor AppleOCRRecognizer: OCRRecognizing {
  nonisolated static let preferredLanguages = ["zh-Hans", "zh-Hant"]

  func recognizeChineseText(in imageData: Data) async throws -> [OCRTextRegion] {
    try Task.checkCancellation()

    guard
      let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
      throw OCRRecognitionError.imageDecodingFailed
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let supportedLanguages = try request.supportedRecognitionLanguages()
    let recognitionLanguages = Self.preferredLanguages.filter(
      supportedLanguages.contains
    )
    guard !recognitionLanguages.isEmpty else {
      throw OCRRecognitionError.noChineseLanguageSupport
    }
    request.recognitionLanguages = recognitionLanguages

    let orientation = imageOrientation(from: imageSource)
    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: orientation,
      options: [:]
    )

    do {
      try handler.perform([request])
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw OCRRecognitionError.recognitionFailed
    }

    try Task.checkCancellation()

    let regions = (request.results ?? []).enumerated().compactMap {
      index,
      observation -> OCRTextRegion? in
      guard let candidate = observation.topCandidates(1).first else {
        return nil
      }

      let transcript = ChineseText.sanitized(candidate.string)
      guard !transcript.isEmpty else { return nil }

      return OCRTextRegion(
        id: index,
        transcript: transcript,
        boundingBox: observation.boundingBox,
        confidence: candidate.confidence,
      )
    }

    guard !regions.isEmpty else {
      throw OCRRecognitionError.noChineseText
    }
    return regions
  }

  private func imageOrientation(
    from imageSource: CGImageSource
  ) -> CGImagePropertyOrientation {
    let properties = CGImageSourceCopyPropertiesAtIndex(
      imageSource,
      0,
      nil
    ) as? [CFString: Any]
    let rawValue = properties?[kCGImagePropertyOrientation] as? UInt32
    return OCRImageOrientation.value(from: rawValue)
  }
}
