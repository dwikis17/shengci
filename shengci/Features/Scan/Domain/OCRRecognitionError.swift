import Foundation

nonisolated enum OCRRecognitionError: LocalizedError {
  case imageDecodingFailed
  case noChineseLanguageSupport
  case noChineseText
  case recognitionFailed

  var errorDescription: String? {
    switch self {
    case .imageDecodingFailed:
      "The selected image could not be opened."
    case .noChineseLanguageSupport:
      "Chinese text recognition is unavailable on this device."
    case .noChineseText:
      "No Chinese text was found in this image."
    case .recognitionFailed:
      "Shengci could not recognize text in this image."
    }
  }
}
