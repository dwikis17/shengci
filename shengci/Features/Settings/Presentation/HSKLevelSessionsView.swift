import SwiftData
import SwiftUI

struct HSKLevelSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSessionRecord.date, order: .reverse)
    private var allSessions: [PracticeSessionRecord]

    let hskLevel: Int
    @State private var showResetAlert = false

    private var levelSessions: [PracticeSessionRecord] {
        allSessions.filter { $0.hskLevel == hskLevel }
    }

    private var levelTitle: String {
        "HSK \(hskLevel == 7 ? "7-9" : "\(hskLevel)")"
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            if levelSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 56))
                        .foregroundColor(Color.darkForeground.opacity(0.35))
                    Text("No Sessions Yet")
                        .font(.headline)
                        .foregroundColor(Color.darkForeground)
                    Text("Complete practice sessions in \(levelTitle) to see your history here.")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    Section {
                        ForEach(levelSessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.royalBlueAccent.opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "checkmark.seal")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Color.royalBlueAccent)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Score: \(session.score) / \(session.totalQuestions)")
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(Color.darkForeground)

                                        Text(session.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(Color.darkForeground.opacity(0.65))
                                            + Text(" at ")
                                            .font(.caption)
                                            .foregroundColor(Color.darkForeground.opacity(0.65))
                                            + Text(session.date, style: .time)
                                            .font(.caption)
                                            .foregroundColor(Color.darkForeground.opacity(0.65))
                                    }

                                    Spacer()

                                    Text("\(session.items.count) words")
                                        .font(.caption.bold())
                                        .foregroundColor(Color.tealAccent)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.warmIvoryCard)
                        }
                    } header: {
                        Text("\(levelSessions.count) Practice Sessions")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(levelTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.creamBackground, for: .navigationBar)
        .toolbar {
            if !levelSessions.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        showResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Reset \(levelTitle) Progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetLevelSessions()
            }
        } message: {
            Text("This will delete all completed practice sessions for \(levelTitle), making words available for practice again.")
        }
    }

    private func resetLevelSessions() {
        for session in levelSessions {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }
}
