import SwiftData
import SwiftUI

struct ScannedWordDetailView: View {
  let token: ScannedToken

  @Environment(\.modelContext) private var modelContext
  @Query private var savedWords: [SavedWord]
  @State private var isShowingSaveError = false
  @State private var saveErrorMessage = ""

  private var canonicalEntry: CEDICTEntry? {
    token.entries.first
  }

  private var savedWord: SavedWord? {
    guard let simplified = canonicalEntry?.simplified else { return nil }
    return savedWords.first { $0.simplified == simplified && $0.isSaved }
  }

  var body: some View {
    Group {
      if token.entries.isEmpty {
        ContentUnavailableView(
          "No Dictionary Entry",
          systemImage: "character.book.closed",
          description: Text(
            "CC-CEDICT does not contain an exact entry for \(token.text)."
          )
        )
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
              Text(token.text)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.darkForeground)

              Spacer()

              Button(
                "Pronounce",
                systemImage: "speaker.wave.2.fill",
                action: speak
              )
              .labelStyle(.iconOnly)
              .buttonStyle(.bordered)

              Button(
                savedWord == nil ? "Save" : "Remove Saved Word",
                systemImage: savedWord == nil
                  ? "bookmark"
                  : "bookmark.fill",
                action: toggleSavedWord
              )
              .labelStyle(.iconOnly)
              .buttonStyle(.borderedProminent)
              .tint(Color.royalBlueAccent)
            }

            ForEach(token.entries) { entry in
              ScannedDictionaryEntryCard(entry: entry)
            }

            Text("Source: CC-CEDICT (MDBG) · CC BY-SA 4.0")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.top)
          }
          .padding()
        }
      }
    }
    .background(Color.creamBackground)
    .navigationTitle("Dictionary")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Couldn’t Update Saved Words", isPresented: $isShowingSaveError) {
    } message: {
      Text(saveErrorMessage)
    }
  }

  private func speak() {
    SpeechSynthesizerManager.shared.speak(token.text)
  }

  private func toggleSavedWord() {
    do {
      if let savedWord {
        savedWord.remove()
      } else if let entry = canonicalEntry {
        if let existing = savedWords.first(where: {
          $0.simplified == entry.simplified
        }) {
          existing.restore()
        } else {
          modelContext.insert(SavedWord(
            simplified: entry.simplified,
            pinyin: entry.pinyin,
            traditional: entry.traditional,
            meanings: entry.definitions
          ))
        }
      }
      try modelContext.save()
    } catch {
      modelContext.rollback()
      saveErrorMessage = error.localizedDescription
      isShowingSaveError = true
    }
  }
}
