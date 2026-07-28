import SwiftUI

struct PracticeView: View {
    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1
    @StateObject private var vocabulary = HomeViewModel()
    @State private var questions: [PracticeQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String?
    @State private var score = 0
    @State private var missedWords: [WordModel] = []

    @State private var isPracticing = false

    private var currentQuestion: PracticeQuestion? {
        questions.indices.contains(currentQuestionIndex) ? questions[currentQuestionIndex] : nil
    }

    private var levelTitle: String {
        "HSK \(selectedHSKLevel == 7 ? "7-9" : "\(selectedHSKLevel)")"
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
            .toolbarColorScheme(.light, for: .navigationBar)
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
        .onChange(of: selectedHSKLevel) { _ in
            resetSession()
            loadSelectedLevel()
        }
    }

    private var startView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 58))
                .foregroundColor(Color.royalBlueAccent)
            VStack(spacing: 8) {
                Text("Recall Practice").font(.title.bold()).foregroundColor(Color.darkForeground)
                Text("Test your \(levelTitle) vocabulary with 10 quick questions.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.darkForeground.opacity(0.65))
            }
            Button(action: startSession) {
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

                Button(action: startSession) {
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
        if vocabulary.currentLevel != selectedHSKLevel || vocabulary.wordList.isEmpty {
            vocabulary.loadWords(level: selectedHSKLevel)
        }
    }

    private func startSession() {
        questions = PracticeQuiz.makeQuestions(from: vocabulary.wordList)
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
        isPracticing = true
    }

    private func endSession() {
        isPracticing = false
        questions = []
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
    }

    private func resetSession() {
        isPracticing = false
        questions = []
        currentQuestionIndex = 0
        selectedAnswer = nil
        score = 0
        missedWords = []
    }

    private func answer(_ choice: String, for question: PracticeQuestion) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = choice
        if question.isCorrect(choice) {
            score += 1
            HapticManager.shared.notification(type: .success)
        } else {
            missedWords.append(question.word)
            HapticManager.shared.notification(type: .error)
        }
    }

    private func nextQuestion() {
        currentQuestionIndex += 1
        selectedAnswer = nil
    }
}

#Preview {
    PracticeView()
}
