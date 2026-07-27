//
//  ContentView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home
        case search
        case saved
        case settings
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 0.07,
            green: 0.09,
            blue: 0.15,
            alpha: 0.95
        )

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Learn", systemImage: "play.rectangle.fill")
                }
                .tag(Tab.home)

            PlaceholderTabView(
                title: "Vocabulary Search",
                icon: "magnifyingglass",
                description:
                    "Search HSK words by Pinyin, English, or Chinese characters."
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)

            SavedWordsView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
                .tag(Tab.saved)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}

// MARK: - Saved Words SwiftData View
struct SavedWordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var savedWords:
        [SavedWord]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.15),
                        Color(red: 0.12, green: 0.10, blue: 0.22),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if savedWords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        Text("No Saved Characters")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(
                            "Tap the heart icon on any word card to save characters here."
                        )
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(savedWords) { item in
                            HStack(spacing: 16) {
                                Text(item.simplified)
                                    .font(
                                        .system(
                                            size: 36,
                                            weight: .bold,
                                            design: .serif
                                        )
                                    )
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(item.pinyin)
                                            .font(.headline)
                                            .foregroundColor(
                                                Color(
                                                    red: 0.25,
                                                    green: 0.82,
                                                    blue: 0.98
                                                )
                                            )

                                        if !item.traditional.isEmpty
                                            && item.traditional
                                                != item.simplified
                                        {
                                            Text("(\(item.traditional))")
                                                .font(.subheadline)
                                                .foregroundColor(
                                                    .white.opacity(0.6)
                                                )
                                        }
                                    }

                                    if !item.meanings.isEmpty {
                                        Text(item.meanings.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundColor(
                                                .white.opacity(0.8)
                                            )
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Button {
                                    SpeechSynthesizerManager.shared.speak(
                                        item.simplified
                                    )
                                } label: {
                                    Image(
                                        systemName: "speaker.wave.2.fill"
                                    )
                                    .font(.title3)
                                    .foregroundColor(
                                        Color(
                                            red: 0.38,
                                            green: 0.35,
                                            blue: 0.95
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                        .onDelete(perform: deleteSavedWords)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Characters (\(savedWords.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color(red: 0.07, green: 0.09, blue: 0.15),
                for: .navigationBar
            )
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func deleteSavedWords(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedWords[index])
        }
    }
}

// MARK: - Placeholder Tab View
struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.15),
                    Color(red: 0.12, green: 0.10, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0.25, green: 0.82, blue: 0.98))

                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedWord.self, inMemory: true)
}
