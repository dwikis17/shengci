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
    @Query private var savedWords: [SavedWord]
    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1
    @StateObject private var viewModel = HomeViewModel()
    @State private var currentWordID: UUID?

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
                .ignoresSafeArea()

                // Pinned Header (Fixed on top, not scrollable)
                HStack {
                    // HSK Level Badge
                    HStack(spacing: 6) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.caption)
                        Text(
                            "HSK \(selectedHSKLevel == 7 ? "7-9" : "\(selectedHSKLevel)")"
                        )
                        .font(.caption.bold())
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

                    Spacer()

                    // Counter Badge (Ultra Thin Material, dark text)
                    Text("\(currentIndex + 1) / \(viewModel.wordList.count)")
                        .font(.caption.monospacedDigit().bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                Color.black.opacity(0.1),
                                lineWidth: 0.5
                            )
                        )
                        .foregroundColor(Color.darkForeground)
                }
                .padding(.horizontal, 24)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if viewModel.currentLevel != selectedHSKLevel {
                viewModel.loadWords(level: selectedHSKLevel)
            }
        }
        .onChange(of: selectedHSKLevel) { newLevel in
            viewModel.loadWords(level: newLevel)
        }
        .onChange(of: viewModel.wordList) { newList in
            if currentWordID == nil
                || !newList.contains(where: { $0.id == currentWordID })
            {
                currentWordID = newList.first?.id
            }
        }
        .onChange(of: currentWordID) { _ in
            HapticManager.shared.selection()
        }
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

// MARK: - Word Card View (TikTok 1-word-per-screen layout)
struct WordCardView: View {
    let word: WordModel
    let isBookmarked: Bool
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
                        Text(pinyin)
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
                            .foregroundColor(isSpeaking ? Color.royalBlueAccent : Color.darkForeground)
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
    static let creamBackground = Color(red: 0.97, green: 0.95, blue: 0.92) // #FAF2EA Warm Cream
    static let warmIvoryCard   = Color(red: 1.0, green: 0.99, blue: 0.97)   // Soft Ivory White
    static let darkForeground   = Color(red: 0.15, green: 0.13, blue: 0.12)  // Deep Espresso Charcoal
    static let royalBlueAccent  = Color(red: 0.20, green: 0.40, blue: 0.80)  // Slate Royal Blue
    static let tealAccent       = Color(red: 0.12, green: 0.60, blue: 0.50)  // Warm Sage Teal
    static let amberAccent      = Color(red: 0.82, green: 0.50, blue: 0.10)  // Terracotta Amber
    static let roseAccent       = Color(red: 0.85, green: 0.25, blue: 0.32)  // Crimson Rose
}

#Preview {
    HomeView()
        .modelContainer(for: SavedWord.self, inMemory: true)
}
