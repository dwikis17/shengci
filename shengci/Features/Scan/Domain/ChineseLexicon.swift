nonisolated protocol ChineseLexicon: Sendable {
  func exactEntries(for terms: Set<String>) async -> [String: [CEDICTEntry]]
}
