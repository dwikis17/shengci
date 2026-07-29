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
        case search
        case scan
        case practice
        case settings
    }

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .creamBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .creamBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.darkForeground]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.darkForeground]

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

                    Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                        NavigationStack {
                            DictionarySearchView()
                        }
                    }

                    Tab("Scan", systemImage: "viewfinder", value: AppTab.scan) {
                        ScanView()
                    }

                    Tab("Practice", systemImage: "brain.head.profile", value: AppTab.practice) {
                        PracticeView()
                    }

                    Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
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

                    NavigationStack {
                        DictionarySearchView()
                    }
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(AppTab.search)

                    ScanView()
                        .tabItem {
                            Label("Scan", systemImage: "viewfinder")
                        }
                        .tag(AppTab.scan)

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
        .onOpenURL { url in
            guard url.scheme == "shengci", url.host == "word" else { return }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let item = components.queryItems?.first(where: { $0.name == "simplified" }),
               let simplified = item.value {
                selectedTab = .home
                let dailyWord = WordOfTheDayManager.shared.getWord(for: Date())
                if dailyWord.simplified == simplified {
                    deepLinkedWord = dailyWord
                } else {
                    // Fallback to daily word if character matches or load directly
                    deepLinkedWord = dailyWord
                }
            }
        }
        .sheet(item: $deepLinkedWord) { word in
            WordOfTheDayDetailSheet(word: word)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    @State private var deepLinkedWord: WordOfTheDay? = nil
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

// MARK: - Word of the Day Detail Sheet
struct WordOfTheDayDetailSheet: View {
    let word: WordOfTheDay
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedWords: [SavedWord]

    @State private var isSpeaking: Bool = false
    @State private var copied: Bool = false

    private var isBookmarked: Bool {
        savedWords.contains(where: { $0.simplified == word.simplified })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Badge Header
                    HStack {
                        Text("WORD OF THE DAY")
                            .font(.caption.bold())
                            .foregroundColor(Color.royalBlueAccent)
                            .tracking(1)

                        Spacer()

                        Text("HSK Level \(word.hskLevel)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.royalBlueAccent.opacity(0.12))
                            .foregroundColor(Color.royalBlueAccent)
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Hero Character Card
                    VStack(spacing: 12) {
                        Text(word.formattedPinyin)
                            .font(.title2.bold())
                            .foregroundColor(Color.royalBlueAccent)

                        Text(word.simplified)
                            .font(.system(size: 80, weight: .bold, design: .serif))
                            .foregroundColor(Color.darkForeground)
                            .onTapGesture {
                                playAudio()
                            }

                        HStack(spacing: 12) {
                            if !word.traditional.isEmpty && word.traditional != word.simplified {
                                Text("Traditional: \(word.traditional)")
                                    .font(.subheadline)
                                    .foregroundColor(Color.darkForeground.opacity(0.6))
                            }

                            if !word.radical.isEmpty {
                                Text("Radical: \(word.radical)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.amberAccent)
                            }
                        }
                    }

                    // Card Container for Meanings, Metadata & Action Icons
                    VStack(alignment: .leading, spacing: 16) {
                        if !word.pos.isEmpty {
                            HStack {
                                ForEach(word.pos, id: \.self) { posTag in
                                    Text(posTag.uppercased())
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.royalBlueAccent.opacity(0.1))
                                        .foregroundColor(Color.royalBlueAccent)
                                        .cornerRadius(4)
                                }
                            }
                        }

                        Text("Meanings")
                            .font(.headline)
                            .foregroundColor(Color.darkForeground)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(word.meanings.enumerated()), id: \.offset) { idx, meaning in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1).")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Color.royalBlueAccent)
                                    Text(meaning)
                                        .font(.subheadline)
                                        .foregroundColor(Color.darkForeground.opacity(0.85))
                                }
                            }
                        }

                        // Divider line
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 1)
                            .padding(.vertical, 2)

                        // Icon-only Action Bar (Matching Learning View)
                        HStack {
                            Spacer()

                            // Audio Icon Button
                            Button {
                                playAudio()
                            } label: {
                                Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.subheadline)
                                    .foregroundColor(isSpeaking ? Color.royalBlueAccent : Color.darkForeground)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }

                            Spacer()

                            // Bookmark / Save Icon Button
                            Button {
                                toggleSave()
                            } label: {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.subheadline)
                                    .foregroundColor(isBookmarked ? Color.roseAccent : Color.darkForeground)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }

                            Spacer()

                            // Copy Icon Button
                            Button {
                                UIPasteboard.general.string = word.simplified
                                HapticManager.shared.notification(type: .success)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copied = false
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.subheadline)
                                    .foregroundColor(copied ? Color.tealAccent : Color.darkForeground)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }

                            Spacer()
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.warmIvoryCard)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Word of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.royalBlueAccent)
                }
            }
        }
    }

    private func playAudio() {
        isSpeaking = true
        HapticManager.shared.impact(style: .light)
        SpeechSynthesizerManager.shared.speak(word.simplified)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isSpeaking = false
        }
    }

    private func toggleSave() {
        HapticManager.shared.impact(style: .medium)
        if let existing = savedWords.first(where: { $0.simplified == word.simplified }) {
            modelContext.delete(existing)
        } else {
            let saved = SavedWord(
                simplified: word.simplified,
                pinyin: word.pinyin,
                traditional: word.traditional,
                meanings: word.meanings,
                radical: word.radical,
                pos: word.pos
            )
            modelContext.insert(saved)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedWord.self, PracticeSessionRecord.self], inMemory: true)
}
