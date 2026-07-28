//
//  HomeView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import AVFoundation
import SwiftData
import SwiftUI
import UIKit

// MARK: - Home Display Mode
enum HomeDisplayMode {
    case focused
    case overview
}

// MARK: - Haptic Feedback Manager
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Text-To-Speech Manager
final class SpeechSynthesizerManager {
    static let shared = SpeechSynthesizerManager()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String = "zh-CN") {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var savedWords: [SavedWord]
    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1
    @StateObject private var viewModel = HomeViewModel()
    @State private var currentWordID: UUID?

    @State private var displayMode: HomeDisplayMode = .focused
    @State private var isLevelPickerPresented: Bool = false
    @State private var isRestoringProgress: Bool = false

    @Namespace private var homeNamespace

    private var currentIndex: Int {
        if let currentWordID = currentWordID,
            let idx = viewModel.wordList.firstIndex(where: {
                $0.id == currentWordID
            })
        {
            return idx
        }
        return 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Warm Cream Background
            Color.creamBackground
                .ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(Color.darkForeground)
                    Text(
                        "Loading HSK \(selectedHSKLevel == 7 ? "7-9" : "\(selectedHSKLevel)") Vocabulary..."
                    )
                    .font(.headline)
                    .foregroundColor(Color.darkForeground.opacity(0.8))
                }
                .frame(maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.amberAccent)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button {
                        viewModel.loadWords(level: selectedHSKLevel)
                    } label: {
                        Text("Retry")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.royalBlueAccent))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.wordList.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(Color.darkForeground.opacity(0.5))
                    Text("No words available")
                        .font(.headline)
                        .foregroundColor(Color.darkForeground.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                // Main Content Views
                Group {
                    if displayMode == .overview {
                        WordOverviewGrid(
                            wordList: viewModel.wordList,
                            currentWordID: $currentWordID,
                            namespace: homeNamespace,
                            isWordSaved: isWordSaved,
                            onSelectWord: { selectedWord in
                                selectWordFromOverview(selectedWord)
                            }
                        )
                        .transition(reduceMotion ? .opacity : .identity)
                    } else {
                        // Scrollable Feed
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(
                                    Array(viewModel.wordList.enumerated()),
                                    id: \.element.id
                                ) { index, word in
                                    WordCardView(
                                        word: word,
                                        isBookmarked: isWordSaved(word),
                                        namespace: homeNamespace,
                                        onToggleBookmark: {
                                            toggleBookmark(for: word)
                                        }
                                    )
                                    .containerRelativeFrame([.horizontal, .vertical])
                                    .id(word.id)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $currentWordID)
                        .background(DisableScrollToTop())
                        .ignoresSafeArea()
                        .transition(reduceMotion ? .opacity : .identity)
                    }
                }
                .simultaneousGesture(pinchGesture)

                // Pinned Header (Fixed on top, not scrollable)
                HStack {
                    // Clickable HSK Level Badge
                    Button {
                        HapticManager.shared.impact(style: .light)
                        isLevelPickerPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "character.book.closed.fill")
                                .font(.caption)
                            Text(
                                "HSK \(selectedHSKLevel == 7 ? "7-9" : "\(selectedHSKLevel)")"
                            )
                            .font(.caption.bold())
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(
                                    Color.darkForeground.opacity(0.65)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                Color.black.opacity(0.1),
                                lineWidth: 1
                            )
                        )
                        .foregroundColor(Color.darkForeground)
                    }

                    Spacer()

                    // Grid / Feed Toggle Button & Counter
                    HStack(spacing: 10) {
                        Button {
                            switchMode(
                                to: displayMode == .focused ? .overview : .focused
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Image(
                                    systemName: displayMode == .focused
                                        ? "square.grid.2x2.fill"
                                        : "rectangle.portrait.on.rectangle.portrait.fill"
                                )
                                .font(.subheadline)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule().stroke(
                                    Color.black.opacity(0.1),
                                    lineWidth: 1
                                )
                            )
                            .foregroundColor(Color.darkForeground)
                        }
                        .accessibilityLabel(
                            displayMode == .focused
                                ? "Switch to Overview Grid"
                                : "Switch to Focused View"
                        )
                        .accessibilityHint(
                            "Toggles between zoomed-out grid and full-screen card feed"
                        )

                        Text("\(currentIndex + 1) / \(viewModel.wordList.count)")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundColor(Color.darkForeground.opacity(0.55))
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $isLevelPickerPresented) {
            HSKLevelPickerSheet(selectedLevel: $selectedHSKLevel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if viewModel.currentLevel != selectedHSKLevel {
                displayMode = .focused
                viewModel.loadWords(level: selectedHSKLevel)
            } else if currentWordID == nil {
                restoreProgress()
            }
        }
        .onChange(of: selectedHSKLevel) { newLevel in
            displayMode = .focused
            viewModel.loadWords(level: newLevel)
        }
        .onChange(of: viewModel.wordList) { _ in
            restoreProgress()
        }
        .onChange(of: currentWordID) { newID in
            guard !isRestoringProgress else { return }
            if displayMode == .focused {
                HapticManager.shared.selection()
            }
            saveProgress(for: newID)
        }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onEnded { finalScale in
                if displayMode == .focused && finalScale < 0.85 {
                    switchMode(to: .overview)
                } else if displayMode == .overview && finalScale > 1.15 {
                    switchMode(to: .focused)
                }
            }
    }

    private func switchMode(to newMode: HomeDisplayMode) {
        guard displayMode != newMode else { return }
        HapticManager.shared.impact(style: .light)
        let animation: Animation? = reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.38, dampingFraction: 0.82)
        withAnimation(animation) {
            displayMode = newMode
        }
    }

    private func selectWordFromOverview(_ word: WordModel) {
        HapticManager.shared.selection()
        currentWordID = word.id
        saveProgress(for: word.id)
        switchMode(to: .focused)
    }

    private func restoreProgress() {
        guard !viewModel.wordList.isEmpty else { return }
        isRestoringProgress = true
        let savedIndex = UserDefaults.standard.integer(
            forKey: "hsk_progress_\(selectedHSKLevel)"
        )
        let validIndex = min(
            max(0, savedIndex),
            viewModel.wordList.count - 1
        )
        currentWordID = viewModel.wordList[validIndex].id
        DispatchQueue.main.async {
            isRestoringProgress = false
        }
    }

    private func saveProgress(for wordID: UUID?) {
        guard let wordID = wordID,
            let idx = viewModel.wordList.firstIndex(where: {
                $0.id == wordID
            })
        else { return }
        UserDefaults.standard.set(
            idx,
            forKey: "hsk_progress_\(selectedHSKLevel)"
        )
    }

    private func isWordSaved(_ word: WordModel) -> Bool {
        savedWords.contains(where: { $0.simplified == word.simplified })
    }

    private func toggleBookmark(for word: WordModel) {
        HapticManager.shared.impact(style: .medium)
        if let existing = savedWords.first(where: {
            $0.simplified == word.simplified
        }) {
            modelContext.delete(existing)
        } else {
            let saved = SavedWord(from: word)
            modelContext.insert(saved)
        }
    }
}

// MARK: - Word Overview Grid Component
struct WordOverviewGrid: View {
    let wordList: [WordModel]
    @Binding var currentWordID: UUID?
    let namespace: Namespace.ID
    let isWordSaved: (WordModel) -> Bool
    let onSelectWord: (WordModel) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 95, maximum: 125), spacing: 12)
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(wordList) { word in
                        WordOverviewTile(
                            word: word,
                            isSelected: word.id == currentWordID,
                            isSaved: isWordSaved(word),
                            namespace: namespace,
                            onSelect: {
                                onSelectWord(word)
                            }
                        )
                        .id(word.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .background(DisableScrollToTop())
            .onAppear {
                if let currentWordID = currentWordID {
                    proxy.scrollTo(currentWordID, anchor: .center)
                }
            }
            .onChange(of: currentWordID) { newID in
                if let newID = newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Word Overview Tile Component
struct WordOverviewTile: View {
    let word: WordModel
    let isSelected: Bool
    let isSaved: Bool
    let namespace: Namespace.ID
    let onSelect: () -> Void

    private var pinyinText: String {
        if let pinyin = word.forms.first?.transcriptions.pinyin {
            return PinyinFormatter.display(pinyin)
        }
        return ""
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.roseAccent)
                    }
                }
                .frame(height: 10)

                Text(word.simplified)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color.darkForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .matchedGeometryEffect(
                        id: "overview-char-\(word.id)",
                        in: namespace
                    )

                if !pinyinText.isEmpty {
                    Text(pinyinText)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(
                            isSelected
                                ? Color.royalBlueAccent
                                : Color.darkForeground.opacity(0.7)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? Color.royalBlueAccent.opacity(0.12)
                            : Color.warmIvoryCard
                    )
                    .matchedGeometryEffect(
                        id: "overview-tile-\(word.id)",
                        in: namespace
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? Color.royalBlueAccent
                            : Color.black.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? Color.royalBlueAccent.opacity(0.15)
                    : Color.black.opacity(0.03),
                radius: isSelected ? 6 : 3,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(word.simplified), \(pinyinText)\(isSaved ? ", Bookmarked" : "")"
        )
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : [.isButton]
        )
        .accessibilityHint("Double tap to jump to this word")
    }
}

// MARK: - Word Card View (TikTok 1-word-per-screen layout)
struct WordCardView: View {
    let word: WordModel
    let isBookmarked: Bool
    let namespace: Namespace.ID
    let onToggleBookmark: () -> Void

    @State private var copiedFeedback: Bool = false
    @State private var isSpeaking: Bool = false

    private var primaryForm: WordForm? {
        word.forms.first
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Hero Character Display
                VStack(spacing: 12) {
                    // Pinyin Pronunciation
                    if let pinyin = primaryForm?.transcriptions.pinyin {
                        Text(PinyinFormatter.display(pinyin))
                            .font(
                                .system(
                                    size: 28,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color.royalBlueAccent)
                    }

                    // Simplified Chinese Character (Espresso Charcoal foreground)
                    Text(word.simplified)
                        .font(.system(size: 96, weight: .bold, design: .serif))
                        .foregroundColor(Color.darkForeground)
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .matchedGeometryEffect(
                            id: "overview-char-\(word.id)",
                            in: namespace
                        )
                        .onTapGesture {
                            playAudio()
                        }

                    // Traditional Variant & Radical Tags
                    HStack(spacing: 10) {
                        if let trad = primaryForm?.traditional,
                            trad != word.simplified
                        {
                            HStack(spacing: 4) {
                                Text("繁")
                                    .font(.caption2.bold())
                                    .padding(3)
                                    .background(Color.black.opacity(0.06))
                                    .cornerRadius(4)
                                Text(trad)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.black.opacity(0.04))
                            )
                            .foregroundColor(Color.darkForeground.opacity(0.85))
                        }

                        // Radical Pill
                        HStack(spacing: 4) {
                            Text("部首")
                                .font(.caption2.bold())
                                .foregroundColor(Color.darkForeground.opacity(0.5))
                            Text(word.radical)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.amberAccent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.04)))
                    }
                }
                .padding(.vertical, 20)

                // Meanings & Metadata Glass Card (Warm Ivory card with soft shadow)
                VStack(alignment: .leading, spacing: 14) {
                    // Part of Speech Badges
                    if !word.pos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(word.pos, id: \.self) { posTag in
                                    Text(posTag.uppercased())
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(
                                                Color.royalBlueAccent.opacity(0.10)
                                            )
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                Color.royalBlueAccent.opacity(0.25),
                                                lineWidth: 1
                                            )
                                        )
                                        .foregroundColor(Color.royalBlueAccent)
                                }

                                Text("Freq #\(word.frequency)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(Color.black.opacity(0.04))
                                    )
                                    .foregroundColor(Color.darkForeground.opacity(0.6))
                            }
                        }
                        .background(DisableScrollToTop())
                    }

                    // Meanings List
                    if let meanings = primaryForm?.meanings, !meanings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(
                                Array(meanings.prefix(4).enumerated()),
                                id: \.offset
                            ) { idx, meaning in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(idx + 1).")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Color.royalBlueAccent)
                                    Text(meaning)
                                        .font(.subheadline)
                                        .foregroundColor(Color.darkForeground.opacity(0.9))
                                        .fixedSize(
                                            horizontal: false,
                                            vertical: true
                                        )
                                }
                            }
                        }
                    }

                    // Classifiers (Measure words) if available
                    if let classifiers = primaryForm?.classifiers,
                        !classifiers.isEmpty
                    {
                        HStack(spacing: 6) {
                            Text("Classifiers:")
                                .font(.caption.bold())
                                .foregroundColor(Color.darkForeground.opacity(0.5))
                            ForEach(classifiers, id: \.self) { classifier in
                                Text(classifier)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6).fill(
                                            Color.black.opacity(0.05)
                                        )
                                    )
                                    .foregroundColor(Color.darkForeground)
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    // Horizontal Action Buttons (Audio, Save, Copy) below meanings
                    HStack {
                        Spacer()

                        // Audio Button
                        Button {
                            playAudio()
                        } label: {
                            HStack(spacing: 6) {
                                Image(
                                    systemName: isSpeaking
                                        ? "speaker.wave.3.fill"
                                        : "speaker.wave.2.fill"
                                )
                                .font(.subheadline)
                            }
                            .foregroundColor(
                                isSpeaking ? Color.royalBlueAccent : Color.darkForeground
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }

                        Spacer()

                        // Bookmark / Save Button
                        Button {
                            onToggleBookmark()
                        } label: {
                            HStack(spacing: 6) {
                                Image(
                                    systemName: isBookmarked
                                        ? "bookmark.fill" : "bookmark"
                                )
                                .font(.subheadline)
                                .foregroundColor(
                                    isBookmarked ? .roseAccent : Color.darkForeground
                                )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }

                        Spacer()

                        // Copy Button (Copies only Hanzi with Haptic Feedback)
                        Button {
                            UIPasteboard.general.string = word.simplified
                            HapticManager.shared.notification(type: .success)
                            copiedFeedback = true
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 1.5
                            ) {
                                copiedFeedback = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(
                                    systemName: copiedFeedback
                                        ? "checkmark" : "doc.on.doc"
                                )
                                .font(.subheadline)
                                .foregroundColor(
                                    copiedFeedback ? Color.tealAccent : Color.darkForeground
                                )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }

                        Spacer()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.warmIvoryCard)
                        .matchedGeometryEffect(
                            id: "overview-tile-\(word.id)",
                            in: namespace
                        )
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 16,
                            x: 0,
                            y: 6
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // Swipe Up Prompt Visual
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                        .foregroundColor(Color.darkForeground.opacity(0.35))
                    Text("Swipe for next word")
                        .font(.caption2)
                        .foregroundColor(Color.darkForeground.opacity(0.35))
                }
                .padding(.bottom, 40)
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
}

// MARK: - Cream Theme Color Palette Extension
extension Color {
    static let creamBackground = Color(
        red: 0.97,
        green: 0.95,
        blue: 0.92
    )  // #FAF2EA Warm Cream
    static let warmIvoryCard = Color(
        red: 1.0,
        green: 0.99,
        blue: 0.97
    )  // Soft Ivory White
    static let darkForeground = Color(
        red: 0.15,
        green: 0.13,
        blue: 0.12
    )  // Deep Espresso Charcoal
    static let royalBlueAccent = Color(
        red: 0.20,
        green: 0.40,
        blue: 0.80
    )  // Slate Royal Blue
    static let tealAccent = Color(
        red: 0.12,
        green: 0.60,
        blue: 0.50
    )  // Warm Sage Teal
    static let amberAccent = Color(
        red: 0.82,
        green: 0.50,
        blue: 0.10
    )  // Terracotta Amber
    static let roseAccent = Color(
        red: 0.85,
        green: 0.25,
        blue: 0.32
    )  // Crimson Rose
}

// MARK: - HSK Level Picker Half-Sheet Component
struct HSKLevelPickerSheet: View {
    @Binding var selectedLevel: Int
    @Environment(\.dismiss) private var dismiss

    struct LevelItem: Identifiable {
        let id: Int
        let title: String
        let description: String
        let badgeColor: Color
    }

    private let levels: [LevelItem] = [
        LevelItem(
            id: 1,
            title: "HSK Level 1",
            description: "Beginner (~500 exclusive words)",
            badgeColor: .blue
        ),
        LevelItem(
            id: 2,
            title: "HSK Level 2",
            description: "Elementary (~1,270 exclusive words)",
            badgeColor: .teal
        ),
        LevelItem(
            id: 3,
            title: "HSK Level 3",
            description: "Pre-Intermediate (~970 exclusive words)",
            badgeColor: .green
        ),
        LevelItem(
            id: 4,
            title: "HSK Level 4",
            description: "Intermediate (~1,000 exclusive words)",
            badgeColor: .orange
        ),
        LevelItem(
            id: 5,
            title: "HSK Level 5",
            description: "Upper-Intermediate (~1,070 exclusive words)",
            badgeColor: .brown
        ),
        LevelItem(
            id: 6,
            title: "HSK Level 6",
            description: "Advanced (~1,140 exclusive words)",
            badgeColor: .red
        ),
        LevelItem(
            id: 7,
            title: "HSK Level 7-9",
            description: "Mastery (~5,630 exclusive words)",
            badgeColor: .purple
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                List {
                    Section {
                        ForEach(levels) { item in
                            Button {
                                HapticManager.shared.selection()
                                selectedLevel = item.id
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(
                                                Color.darkForeground
                                            )

                                        Text(item.description)
                                            .font(.caption)
                                            .foregroundColor(
                                                Color.darkForeground.opacity(
                                                    0.65
                                                )
                                            )
                                    }

                                    Spacer()

                                    if selectedLevel == item.id {
                                        Image(
                                            systemName: "checkmark.circle.fill"
                                        )
                                        .font(.title3)
                                        .foregroundColor(Color.royalBlueAccent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.warmIvoryCard)
                        }
                    } header: {
                        Text("Select Vocabulary Level")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("HSK Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.creamBackground, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

private final class DisableScrollToTopView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        disableScrollToTop()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        disableScrollToTop()
    }

    func disableScrollToTop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var current: UIView? = self
            while let view = current {
                if let scrollView = view as? UIScrollView {
                    scrollView.scrollsToTop = false
                }
                current = view.superview
            }
            if let window = self.window {
                self.disableAllScrollsToTop(in: window)
            }
        }
    }

    private func disableAllScrollsToTop(in view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.scrollsToTop = false
        }
        for subview in view.subviews {
            disableAllScrollsToTop(in: subview)
        }
    }
}

private struct DisableScrollToTop: UIViewRepresentable {
    func makeUIView(context: Context) -> DisableScrollToTopView {
        DisableScrollToTopView()
    }

    func updateUIView(_ uiView: DisableScrollToTopView, context: Context) {
        uiView.disableScrollToTop()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: SavedWord.self, inMemory: true)
}
