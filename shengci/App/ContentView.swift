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
            red: 0.97,
            green: 0.95,
            blue: 0.92,
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
                    Label("Saved", systemImage: "heart.fill")
                }
                .tag(Tab.saved)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color.royalBlueAccent)
    }
}

// MARK: - Saved Words SwiftData View (Cream theme)
struct SavedWordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var savedWords:
        [SavedWord]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                if savedWords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundColor(Color.darkForeground.opacity(0.35))
                        Text("No Saved Characters")
                            .font(.headline)
                            .foregroundColor(Color.darkForeground)
                        Text(
                            "Tap the bookmark icon on any word card to save characters here."
                        )
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.6))
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
                                    .foregroundColor(Color.darkForeground)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(item.pinyin)
                                            .font(.headline)
                                            .foregroundColor(Color.royalBlueAccent)

                                        if !item.traditional.isEmpty
                                            && item.traditional
                                                != item.simplified
                                        {
                                            Text("(\(item.traditional))")
                                                .font(.subheadline)
                                                .foregroundColor(
                                                    Color.darkForeground.opacity(0.5)
                                                )
                                        }
                                    }

                                    if !item.meanings.isEmpty {
                                        Text(item.meanings.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundColor(
                                                Color.darkForeground.opacity(0.75)
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
                                    .foregroundColor(Color.royalBlueAccent)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Color.warmIvoryCard)
                        }
                        .onDelete(perform: deleteSavedWords)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Characters (\(savedWords.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color.creamBackground,
                for: .navigationBar
            )
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private func deleteSavedWords(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedWords[index])
        }
    }
}

// MARK: - Placeholder Tab View (Cream theme)
struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundColor(Color.royalBlueAccent)

                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(Color.darkForeground)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.darkForeground.opacity(0.65))
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
