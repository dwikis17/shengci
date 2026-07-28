//
//  SettingsView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                List {

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

                    // MARK: - Progress Navigation Section
                    Section {
                        NavigationLink {
                            PracticeProgressView()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.tealAccent.opacity(0.15))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.tealAccent)
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text("Practice Progress")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(
                                            Color.darkForeground
                                        )

                                    Text(
                                        "View completed words grouped by HSK level"
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
                        Text("Progress")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }

                    // MARK: - Search Navigation Section
                    Section {
                        NavigationLink {
                            DictionarySearchView()
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
                                        "Search Chinese, pinyin, or English"
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
        }
    }
}

#Preview {
    SettingsView()
}
