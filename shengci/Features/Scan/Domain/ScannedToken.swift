nonisolated struct ScannedToken: Identifiable, Hashable, Sendable {
  let id: String
  let text: String
  let entries: [CEDICTEntry]
}
