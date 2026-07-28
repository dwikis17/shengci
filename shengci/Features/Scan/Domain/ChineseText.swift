import Foundation

nonisolated enum ChineseText {
  static func sanitized(_ value: String) -> String {
    runs(in: value).joined(separator: " ")
  }

  static func runs(in value: String) -> [String] {
    value
      .split(whereSeparator: { !$0.isHanzi })
      .map(String.init)
      .filter { !$0.isEmpty }
  }

  static func characters(in value: String) -> [String] {
    value.compactMap { character in
      character.isHanzi ? String(character) : nil
    }
  }
}
