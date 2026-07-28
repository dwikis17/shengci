import CoreGraphics

nonisolated struct OCRTextRegion: Identifiable, Equatable, Sendable {
  let id: Int
  let transcript: String
  let boundingBox: CGRect
  let confidence: Float
}
