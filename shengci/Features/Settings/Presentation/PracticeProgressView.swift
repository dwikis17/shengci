import SwiftData
import SwiftUI

struct PracticeProgressView: View {
    @Query private var allSessions: [PracticeSessionRecord]

    private let hskLevels = [1, 2, 3, 4, 5, 6, 7]

    private func levelTitle(_ level: Int) -> String {
        "HSK \(level == 7 ? "7-9" : "\(level)")"
    }

    private func sessionCount(for level: Int) -> Int {
        allSessions.filter { $0.hskLevel == level }.count
    }

    private func uniqueWordCount(for level: Int) -> Int {
        let levelSessions = allSessions.filter { $0.hskLevel == level }
        let words = levelSessions.flatMap { $0.items.map { $0.simplified } }
        return Set(words).count
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            List {
                Section {
                    ForEach(hskLevels, id: \.self) { level in
                        let sCount = sessionCount(for: level)
                        let wCount = uniqueWordCount(for: level)

                        NavigationLink {
                            HSKLevelSessionsView(hskLevel: level)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.royalBlueAccent.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Text("\(level == 7 ? "7+" : "\(level)")")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.royalBlueAccent)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(levelTitle(level))
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(Color.darkForeground)

                                    if sCount > 0 {
                                        Text("\(sCount) \(sCount == 1 ? "session" : "sessions") • \(wCount) \(wCount == 1 ? "word" : "words") practiced")
                                            .font(.caption)
                                            .foregroundColor(Color.darkForeground.opacity(0.65))
                                    } else {
                                        Text("No sessions completed yet")
                                            .font(.caption)
                                            .foregroundColor(Color.darkForeground.opacity(0.45))
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.warmIvoryCard)
                    }
                } header: {
                    Text("Select HSK Level")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.darkForeground.opacity(0.6))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Practice Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Color.creamBackground,
            for: .navigationBar
        )
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PracticeProgressView()
            .modelContainer(for: PracticeSessionRecord.self, inMemory: true)
    }
}
