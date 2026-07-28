import Foundation

nonisolated struct ScannedTextSelection: Identifiable, Equatable, Sendable {
  let id: UUID
  let transcript: String

  init(id: UUID = UUID(), transcript: String) {
    self.id = id
    self.transcript = transcript
  }
}
