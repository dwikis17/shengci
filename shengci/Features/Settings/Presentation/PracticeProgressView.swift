import SwiftData
import SwiftUI

struct PracticeProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticedWord.lastPracticedAt, order: .reverse)
    private var practicedWords: [PracticedWord]

    @State private var levelToReset: Int?
    @State private var showResetAlert = false

    private let hskLevels = [1, 2, 3, 4, 5, 6, 7]

    private func levelTitle(_ level: Int) -> String {
        "HSK \(level == 7 ? "7-9" : "\(level)")"
    }

    private func wordsForLevel(_ level: Int) -> [PracticedWord] {
        practicedWords.filter { $0.hskLevel == level }
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            if practicedWords.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 56))
                        .foregroundColor(Color.darkForeground.opacity(0.35))
                    Text("No Practice Progress Yet")
                        .font(.headline)
                        .foregroundColor(Color.darkForeground)
                    Text("Complete vocabulary practice sessions to track your mastered words here.")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    ForEach(hskLevels, id: \.self) { level in
                        let words = wordsForLevel(level)
                        if !words.isEmpty {
                            Section {
                                ForEach(words) { item in
                                    HStack(spacing: 14) {
                                        Text(item.simplified)
                                            .font(.system(size: 32, weight: .bold, design: .serif))
                                            .foregroundColor(Color.darkForeground)

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 8) {
                                                Text(PinyinFormatter.display(item.pinyin))
                                                    .font(.headline)
                                                    .foregroundColor(Color.royalBlueAccent)

                                                if !item.traditional.isEmpty && item.traditional != item.simplified {
                                                    Text("(\(item.traditional))")
                                                        .font(.subheadline)
                                                        .foregroundColor(Color.darkForeground.opacity(0.5))
                                                }
                                            }

                                            if !item.meanings.isEmpty {
                                                Text(item.meanings.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundColor(Color.darkForeground.opacity(0.75))
                                                    .lineLimit(2)
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(item.timesPracticed)x")
                                                .font(.caption.bold())
                                                .foregroundColor(Color.tealAccent)
                                            Text(item.lastPracticedAt, style: .date)
                                                .font(.caption2)
                                                .foregroundColor(Color.darkForeground.opacity(0.5))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.warmIvoryCard)
                                }
                            } header: {
                                HStack {
                                    Text("\(levelTitle(level)) — \(words.count) Completed")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(Color.darkForeground.opacity(0.7))
                                    Spacer()
                                    Button("Reset") {
                                        levelToReset = level
                                        showResetAlert = true
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Practice Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Color.creamBackground,
            for: .navigationBar
        )
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                if let level = levelToReset {
                    resetLevelProgress(level)
                }
            }
        } message: {
            if let level = levelToReset {
                Text("This will clear all completed practice records for \(levelTitle(level)), making words available for practice again.")
            } else {
                Text("Clear practice records?")
            }
        }
    }

    private func resetLevelProgress(_ level: Int) {
        let targets = wordsForLevel(level)
        for item in targets {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        PracticeProgressView()
            .modelContainer(for: PracticedWord.self, inMemory: true)
    }
}
