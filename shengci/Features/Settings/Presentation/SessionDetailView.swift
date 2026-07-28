import SwiftUI

struct SessionDetailView: View {
    let session: PracticeSessionRecord

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.date)
    }

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Score: \(session.score) / \(session.totalQuestions)")
                        .font(.title2.bold())
                        .foregroundColor(Color.royalBlueAccent)

                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.warmIvoryCard)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                List {
                    Section {
                        ForEach(session.items) { item in
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

                                Image(systemName: item.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(item.isCorrect ? Color.tealAccent : .red)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.warmIvoryCard)
                        }
                    } header: {
                        Text("Practiced Words (\(session.items.count))")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.creamBackground, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
