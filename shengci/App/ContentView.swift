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
    @State private var selectedTab: AppTab = .home

    enum AppTab: Hashable {
        case home
        case practice
        case settings
    }

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(
            red: 0.97,
            green: 0.95,
            blue: 0.92,
            alpha: 0.95
        )

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(
            red: 0.97,
            green: 0.95,
            blue: 0.92,
            alpha: 0.95
        )
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TabView(selection: $selectedTab) {
                    Tab("Learn", systemImage: "play.rectangle.fill", value: AppTab.home) {
                        HomeView()
                    }

                    Tab("Practice", systemImage: "brain.head.profile", value: AppTab.practice) {
                        PracticeView()
                    }

                    Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings, role: .search) {
                        SettingsView()
                    }
                }
                .tint(Color.royalBlueAccent)
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Label("Learn", systemImage: "play.rectangle.fill")
                        }
                        .tag(AppTab.home)

                    PracticeView()
                        .tabItem {
                            Label("Practice", systemImage: "brain.head.profile")
                        }
                        .tag(AppTab.practice)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(AppTab.settings)
                }
                .tint(Color.royalBlueAccent)
            }
        }
        .task {
            await CEDICTStore.shared.warm()
        }
    }
}

// MARK: - Saved Words SwiftData View (Cream theme)
struct SavedWordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var savedWords:
        [SavedWord]

    var body: some View {
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
                                    Text(PinyinFormatter.display(item.pinyin))
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
        .toolbar(.hidden, for: .tabBar)
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
        .modelContainer(for: [SavedWord.self, PracticedWord.self], inMemory: true)
}
