import SwiftData
import SwiftUI

struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptions
    @Query private var sessionRecords: [PracticeSessionRecord]

    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1
    @AppStorage("lastFreePracticeStartedAt")
    private var lastFreePracticeStartedAt: Double = 0
    @StateObject private var vocabulary = HomeViewModel()
    @State private var questions: [PracticeQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String?
    @State private var score = 0
    @State private var missedWords: [WordModel] = []
    @State private var currentSessionItems: [SessionWordItem] = []

    @State private var isPracticing = false
    @State private var isPaywallPresented = false
    @State private var hasPendingPracticeStart = false

    private var accessibleLevel: Int {
        subscriptions.access.allowsHSKLevel(selectedHSKLevel)
            ? selectedHSKLevel
            : 2
    }

    private var currentQuestion: PracticeQuestion? {
        questions.indices.contains(currentQuestionIndex) ? questions[currentQuestionIndex] : nil
    }

    private var levelTitle: String {
        "HSK \(accessibleLevel == 7 ? "7-9" : "\(accessibleLevel)")"
    }

    private var levelPracticedWordSet: Set<String> {
        let levelSessions = sessionRecords.filter {
            $0.hskLevel == accessibleLevel
        }
        return Set(levelSessions.flatMap { $0.items.map { $0.simplified } })
    }

    private var availableWordsToPractice: [WordModel] {
        let unpracticed = vocabulary.wordList.filter { !levelPracticedWordSet.contains($0.simplified) }
        return unpracticed.isEmpty ? vocabulary.wordList : unpracticed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground.ignoresSafeArea()

                if vocabulary.isLoading {
                    ProgressView("Loading \(levelTitle) vocabulary...")
                        .tint(Color.royalBlueAccent)
                } else if let error = vocabulary.errorMessage {
                    unavailableView(message: error)
                } else if let question = currentQuestion {
                    questionView(question)
                } else if !questions.isEmpty {
                    resultsView
                } else {
                    startView
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color.creamBackground,
                for: .navigationBar
            )
            .toolbar {
                if isPracticing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: endSession) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.darkForeground)
                        }
                    }
                }
            }
            .toolbar(isPracticing ? .hidden : .visible, for: .tabBar)
        }
        .onAppear(perform: loadSelectedLevel)
        .onChange(of: selectedHSKLevel) {
            resetSession()
            loadSelectedLevel()
        }
        .onChange(of: subscriptions.isPremium) {
            resetSession()
            loadSelectedLevel()
        }
        .sheet(
            isPresented: $isPaywallPresented,
            onDismiss: startPendingPracticeIfUnlocked
        ) {
            PremiumPaywall()
        }
    }

    private var startView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 58))
                .foregroundColor(Color.royalBlueAccent)
            VStack(spacing: 8) {
                Text("Recall Practice").font(.title.bold()).foregroundColor(Color.darkForeground)
                if !vocabulary.wordList.isEmpty && levelPracticedWordSet.count >= vocabulary.wordList.count {
                    Text("All \(vocabulary.wordList.count) words in \(levelTitle) completed! Practice again to review.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                } else {
                    Text("Test your \(levelTitle) vocabulary (\(levelPracticedWordSet.count)/\(vocabulary.wordList.count) completed).")
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.darkForeground.opacity(0.65))
                }
            }
            Button(action: requestPracticeStart) {
                Label("Start Practice", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.royalBlueAccent))
                    .foregroundColor(.white)
            }
            .disabled(vocabulary.wordList.isEmpty)
        }
        .padding(32)
    }

    private func questionView(_ question: PracticeQuestion) -> some View {
        VStack(spacing: 24) {
            Text("\(currentQuestionIndex + 1) / \(questions.count)")
                .font(.caption.monospacedDigit().bold())
                .foregroundColor(Color.darkForeground.opacity(0.55))
            VStack(spacing: 8) {
                Text(question.word.simplified)
                    .font(.system(size: 76, weight: .bold, design: .serif))
                    .foregroundColor(Color.darkForeground)
                Text(
                    PinyinFormatter.display(
                        question.word.forms.first?.transcriptions.pinyin ?? ""
                    )
                )
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.royalBlueAccent)
            }
            .padding(.bottom, 12)
            Text("Choose the meaning").font(.headline).foregroundColor(Color.darkForeground)

            VStack(spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    Button { answer(choice, for: question) } label: {
                        HStack {
                            Text(choice).multilineTextAlignment(.leading)
                            Spacer()
                            if selectedAnswer != nil && question.isCorrect(choice) {
                                Image(systemName: "checkmark.circle.fill")
                            } else if selectedAnswer == choice {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(choiceColor(choice, for: question))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(choiceBackground(choice, for: question))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswer != nil)
                }
            }

            if selectedAnswer != nil {
                Button(action: nextQuestion) {
                    Text(currentQuestionIndex + 1 == questions.count ? "See Results" : "Next")
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.royalBlueAccent))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
    }

    private var resultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 58)).foregroundColor(Color.tealAccent)
            Text("Session Complete").font(.title.bold()).foregroundColor(Color.darkForeground)
            Text("\(score) / \(questions.count) correct")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color.royalBlueAccent)
            if !missedWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review").font(.headline).foregroundColor(Color.darkForeground)
                    ForEach(missedWords) { word in
                        Text("\(word.simplified) — \(word.forms.first?.meanings.joined(separator: ", ") ?? "")")
                            .foregroundColor(Color.darkForeground.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.warmIvoryCard, in: RoundedRectangle(cornerRadius: 16))
            }
            HStack(spacing: 16) {
                Button(action: endSession) {
                    Label("Finish", systemImage: "checkmark")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Capsule().stroke(Color.royalBlueAccent, lineWidth: 2))
                        .foregroundColor(Color.royalBlueAccent)
                }

                Button(action: requestPracticeStart) {
                    Label("Practice Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.royalBlueAccent))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(24)
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundColor(.amberAccent)
            Text(message).multilineTextAlignment(.center).foregroundColor(Color.darkForeground)
            Button("Retry", action: loadSelectedLevel).buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private func choiceColor(_ choice: String, for question: PracticeQuestion) -> Color {
        guard selectedAnswer != nil else { return Color.darkForeground }
        if question.isCorrect(choice) { return .tealAccent }
        if selectedAnswer == choice { return .red }
        return Color.darkForeground.opacity(0.55)
    }

    private func choiceBackground(_ choice: String, for question: PracticeQuestion) -> Color {
        guard selectedAnswer != nil else { return .warmIvoryCard }
        if question.isCorrect(choice) { return .tealAccent.opacity(0.12) }
        if selectedAnswer == choice { return .red.opacity(0.10) }
        return .warmIvoryCard
    }

    private func loadSelectedLevel() {
        if vocabulary.currentLevel != accessibleLevel
            || vocabulary.wordList.isEmpty
        {
            vocabulary.loadWords(level: accessibleLevel)
        }
    }

    private func requestPracticeStart() {
        let now = Date()
        let lastFreePracticeAt =
            lastFreePracticeStartedAt > 0
            ? Date(timeIntervalSince1970: lastFreePracticeStartedAt)
            : nil

        guard subscriptions.access.allowsPractice(
            lastFreePracticeAt: lastFreePracticeAt,
            now: now
        ) else {
            hasPendingPracticeStart = true
            isPaywallPresented = true
            return
        }

        if !subscriptions.isPremium {
            lastFreePracticeStartedAt = now.timeIntervalSince1970
        }
        startSession()
    }

    private func startPendingPracticeIfUnlocked() {
        guard hasPendingPracticeStart else { return }
        hasPendingPracticeStart = false
        guard subscriptions.isPremium else { return }
        startSession()
    }

    private func startSession() {
        saveSessionRecord()
        let questionSource = availableWordsToPractice
        questions = PracticeQuiz.makeQuestions(
            from: questionSource,
            distractorPool: vocabulary.wordList
        )
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
        currentSessionItems = []
        isPracticing = true
    }

    private func endSession() {
        saveSessionRecord()
        isPracticing = false
        questions = []
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
        currentSessionItems = []
    }

    private func resetSession() {
        saveSessionRecord()
        isPracticing = false
        questions = []
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
        currentSessionItems = []
    }

    private func answer(_ choice: String, for question: PracticeQuestion) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = choice
        let isCorrect = question.isCorrect(choice)
        if isCorrect {
            score += 1
            HapticManager.shared.notification(type: .success)
        } else {
            missedWords.append(question.word)
            HapticManager.shared.notification(type: .error)
        }

        let primaryForm = question.word.forms.first
        let item = SessionWordItem(
            simplified: question.word.simplified,
            traditional: primaryForm?.traditional ?? question.word.simplified,
            pinyin: primaryForm?.transcriptions.pinyin ?? "",
            meanings: primaryForm?.meanings ?? [],
            isCorrect: isCorrect,
            selectedChoice: choice
        )
        currentSessionItems.append(item)
    }

    private func saveSessionRecord() {
        guard !currentSessionItems.isEmpty else { return }
        let record = PracticeSessionRecord(
            hskLevel: accessibleLevel,
            date: Date(),
            score: score,
            totalQuestions: currentSessionItems.count,
            items: currentSessionItems
        )
        modelContext.insert(record)
        try? modelContext.save()
        currentSessionItems = []
    }

    private func nextQuestion() {
        currentQuestionIndex += 1
        selectedAnswer = nil
        if currentQuestionIndex >= questions.count {
            saveSessionRecord()
        }
    }
}

#Preview {
    PracticeView()
        .environment(SubscriptionManager())
}
