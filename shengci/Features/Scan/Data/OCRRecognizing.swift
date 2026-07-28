import Foundation

nonisolated protocol OCRRecognizing: Sendable {
  func recognizeChineseText(in imageData: Data) async throws -> [OCRTextRegion]
}
