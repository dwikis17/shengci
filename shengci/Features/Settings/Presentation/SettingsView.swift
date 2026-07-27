//
//  SettingsView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1

    struct HSKLevelOption: Identifiable {
        let id: Int
        let title: String
        let description: String
        let badgeColor: Color
    }

    private let hskLevels: [HSKLevelOption] = [
        HSKLevelOption(
            id: 1,
            title: "HSK Level 1",
            description: "Beginner level (~500 exclusive words)",
            badgeColor: .blue
        ),
        HSKLevelOption(
            id: 2,
            title: "HSK Level 2",
            description: "Elementary level (~1,270 exclusive words)",
            badgeColor: .teal
        ),
        HSKLevelOption(
            id: 3,
            title: "HSK Level 3",
            description: "Pre-Intermediate level (~970 exclusive words)",
            badgeColor: .green
        ),
        HSKLevelOption(
            id: 4,
            title: "HSK Level 4",
            description: "Intermediate level (~1,000 exclusive words)",
            badgeColor: .orange
        ),
        HSKLevelOption(
            id: 5,
            title: "HSK Level 5",
            description: "Upper-Intermediate level (~1,070 exclusive words)",
            badgeColor: .brown
        ),
        HSKLevelOption(
            id: 6,
            title: "HSK Level 6",
            description: "Advanced level (~1,140 exclusive words)",
            badgeColor: .red
        ),
        HSKLevelOption(
            id: 7,
            title: "HSK Level 7-9",
            description:
                "Mastery / Professional level (~5,630 exclusive words)",
            badgeColor: .purple
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                List {
                    // MARK: - HSK Level Selection Section
                    Section {
                        ForEach(hskLevels) { levelOption in
                            Button {
                                withAnimation(.easeInOut) {
                                    selectedHSKLevel = levelOption.id
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                levelOption.badgeColor
                                                    .opacity(0.15)
                                            )
                                            .frame(width: 38, height: 38)

                                        Text(
                                            "\(levelOption.id == 7 ? "7-9" : "\(levelOption.id)")"
                                        )
                                        .font(.subheadline.bold())
                                        .foregroundColor(
                                            levelOption.badgeColor
                                        )
                                    }

                                    VStack(
                                        alignment: .leading,
                                        spacing: 2
                                    ) {
                                        Text(levelOption.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(
                                                Color.darkForeground
                                            )

                                        Text(levelOption.description)
                                            .font(.caption)
                                            .foregroundColor(
                                                Color.darkForeground
                                                    .opacity(0.65)
                                            )
                                    }

                                    Spacer()

                                    if selectedHSKLevel == levelOption.id {
                                        Image(
                                            systemName: "checkmark.circle.fill"
                                        )
                                        .font(.title3)
                                        .foregroundColor(
                                            Color.royalBlueAccent
                                        )
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.warmIvoryCard)
                        }
                    } header: {
                        Text("HSK Level (Exclusive)")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    } footer: {
                        Text(
                            "Select an HSK 3.0 level to update the vocabulary card feed on the Learn tab. Exclusive wordlists contain words unique to each HSK level."
                        )
                        .font(.caption)
                        .foregroundColor(Color.darkForeground.opacity(0.55))
                    }

                    // MARK: - Saved Characters Navigation Section
                    Section {
                        NavigationLink {
                            SavedWordsView()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.roseAccent.opacity(0.15))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.roseAccent)
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text("Saved Characters")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(
                                            Color.darkForeground
                                        )

                                    Text(
                                        "View and listen to your saved words"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        Color.darkForeground
                                            .opacity(0.65)
                                    )
                                }
                            }
                        }
                        .listRowBackground(Color.warmIvoryCard)
                    } header: {
                        Text("Saved")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }

                    // MARK: - Search Navigation Section
                    Section {
                        NavigationLink {
                            PlaceholderTabView(
                                title: "Vocabulary Search",
                                icon: "magnifyingglass",
                                description:
                                    "Search HSK words by Pinyin, English, or Chinese characters."
                            )
                            .navigationTitle("Search")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            Color.royalBlueAccent.opacity(0.15)
                                        )
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.royalBlueAccent)
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text("Vocabulary Search")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(
                                            Color.darkForeground
                                        )

                                    Text(
                                        "Search HSK words by Pinyin or English"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        Color.darkForeground
                                            .opacity(0.65)
                                    )
                                }
                            }
                        }
                        .listRowBackground(Color.warmIvoryCard)
                    } header: {
                        Text("Search")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color.creamBackground,
                for: .navigationBar
            )
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

#Preview {
    SettingsView()
}
