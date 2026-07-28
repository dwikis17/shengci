import SwiftUI

struct ScannedDictionaryEntryCard: View {
  let entry: CEDICTEntry

  private var definitions: String {
    entry.definitions
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "; ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(PinyinFormatter.display(entry.pinyin))
          .font(.headline)
          .foregroundStyle(Color.royalBlueAccent)

        if entry.traditional != entry.simplified {
          Text(entry.traditional)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Text(definitions)
        .font(.body)
        .foregroundStyle(Color.darkForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.warmIvoryCard)
    .clipShape(.rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.black.opacity(0.06), lineWidth: 1)
    }
  }
}
