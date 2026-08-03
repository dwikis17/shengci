import SwiftUI

struct StrokeOrderLessonView: View {
    let word: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    private let characters: [String]
    private let dataStore: StrokeOrderDataStore

    @State private var characterIndex = 0
    @State private var strokeIndex = 0
    @State private var drawnStrokes: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var isCharacterComplete = false
    @State private var isAdvancingStroke = false
    @State private var validationMessage: String?
    @State private var isValidationError = false
    @State private var isAnimating = false
    @State private var animationStrokeIndex = 0
    @State private var animationProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var transitionTask: Task<Void, Never>?
    @State private var validationFeedbackTask: Task<Void, Never>?
    @State private var hasAppeared = false

    private let validator = StrokeOrderStrokeValidator()

    init(word: String, dataStore: StrokeOrderDataStore? = nil) {
        self.word = word
        characters = ChineseText.characters(in: word)
        self.dataStore = dataStore ?? .bundled
    }

    private var currentCharacter: String? {
        characters.indices.contains(characterIndex)
            ? characters[characterIndex]
            : nil
    }

    private var currentData: StrokeOrderCharacter? {
        guard let currentCharacter else { return nil }
        return dataStore.character(for: currentCharacter)
    }

    private var isLastCharacter: Bool {
        characterIndex == characters.count - 1
    }

    var body: some View {
        ZStack {
            Color.creamBackground.ignoresSafeArea()

            if characters.isEmpty {
                unavailableView(message: "This word has no Chinese characters to practice.")
            } else {
                lessonContent
            }
        }
        .navigationTitle("Learn to Write")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.creamBackground, for: .navigationBar)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            transitionTask?.cancel()
            validationFeedbackTask?.cancel()
        }
    }

    private var lessonContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                progressHeader

                if let currentCharacter {
                    Text(currentCharacter)
                        .font(.system(size: 92, weight: .bold, design: .serif))
                        .foregroundStyle(Color.darkForeground)
                        .accessibilityLabel("Character \(currentCharacter)")
                }

                if let currentData {
                    tutorContent(for: currentData)
                } else {
                    unavailableView(
                        message: "Stroke order is unavailable for \(currentCharacter ?? "this character")."
                    )
                    characterNavigationButton
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
    }

    private var progressHeader: some View {
        HStack {
            Text("Character \(characterIndex + 1) of \(characters.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.darkForeground.opacity(0.6))

            Spacer()

            if let currentData {
                Text(
                    isCharacterComplete
                        ? "Complete"
                        : "Stroke \(strokeIndex + 1) of \(currentData.strokes.count)"
                )
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(
                    isCharacterComplete
                        ? Color.tealAccent
                        : Color.royalBlueAccent
                )
            }
        }
    }

    private func tutorContent(for character: StrokeOrderCharacter) -> some View {
        VStack(spacing: 16) {
            Text(
                isAnimating
                    ? "Watch the correct stroke order"
                    : isCharacterComplete
                        ? "Character complete"
                        : "Trace the highlighted stroke"
            )
            .font(.headline)
            .foregroundStyle(Color.darkForeground)
            .multilineTextAlignment(.center)

            tutorCanvas(for: character)

            HStack(spacing: 12) {
                Button(action: replay) {
                    Label("Replay", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(Color.royalBlueAccent)
                .disabled(currentData == nil)
                .accessibilityIdentifier("stroke-order-replay")

                Button(action: clearCurrentStroke) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(Color.roseAccent)
                .disabled(
                    isAnimating
                        || isAdvancingStroke
                        || currentLine.isEmpty
                )
                .accessibilityIdentifier("stroke-order-clear")
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "arrow.uturn.backward.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.roseAccent)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .accessibilityLabel(validationMessage)
            }

            if isCharacterComplete {
                characterNavigationButton
            }
        }
    }

    @ViewBuilder
    private func tutorCanvas(for character: StrokeOrderCharacter) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.warmIvoryCard
                guideGrid

                Canvas { context, size in
                    render(
                        character,
                        in: &context,
                        rect: CGRect(origin: .zero, size: size)
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            appendPoint(value.location)
                        }
                        .onEnded { value in
                            finishStroke(
                                at: value.location,
                                in: CGRect(origin: .zero, size: geometry.size)
                            )
                        }
                )
                .allowsHitTesting(
                    !isAnimating
                        && !isCharacterComplete
                        && !isAdvancingStroke
                        && currentData != nil
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(canvasAccessibilityLabel(for: character))
                .accessibilityIdentifier("stroke-order-canvas")
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isValidationError
                            ? Color.roseAccent.opacity(0.65)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            }
        }
        .frame(height: 280)
    }

    private var guideGrid: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width / 2, y: 0))
                path.addLine(
                    to: CGPoint(
                        x: geometry.size.width / 2,
                        y: geometry.size.height
                    )
                )
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(
                    to: CGPoint(
                        x: geometry.size.width,
                        y: geometry.size.height / 2
                    )
                )
            }
            .stroke(
                Color.royalBlueAccent.opacity(0.1),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
        }
        .allowsHitTesting(false)
    }

    private func render(
        _ character: StrokeOrderCharacter,
        in context: inout GraphicsContext,
        rect: CGRect
    ) {
        if isAnimating {
            renderAnimation(character, in: &context, rect: rect)
        } else {
            for stroke in drawnStrokes {
                renderUserStroke(stroke, in: &context)
            }

            if isCharacterComplete {
                for stroke in character.strokes {
                    context.fill(
                        Path(stroke.cgPath(in: rect)),
                        with: .color(Color.tealAccent.opacity(0.14))
                    )
                }
            } else if character.strokes.indices.contains(strokeIndex) {
                renderGuide(
                    character.strokes[strokeIndex],
                    in: &context,
                    rect: rect
                )
            }

            renderUserStroke(currentLine, in: &context)
        }
    }

    private func renderAnimation(
        _ character: StrokeOrderCharacter,
        in context: inout GraphicsContext,
        rect: CGRect
    ) {
        guard character.strokes.indices.contains(animationStrokeIndex) else {
            return
        }

        for index in 0..<animationStrokeIndex {
            context.fill(
                Path(character.strokes[index].cgPath(in: rect)),
                with: .color(Color.darkForeground.opacity(0.8))
            )
        }

        let stroke = character.strokes[animationStrokeIndex]
        context.fill(
            Path(stroke.cgPath(in: rect)),
            with: .color(Color.royalBlueAccent.opacity(0.14))
        )

        let median = Path(stroke.medianPath(in: rect))
            .trimmedPath(from: 0, to: animationProgress)
        context.stroke(
            median,
            with: .color(Color.royalBlueAccent),
            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        )
        renderStartMarker(stroke, in: &context, rect: rect)
    }

    private func renderGuide(
        _ stroke: StrokeOrderStroke,
        in context: inout GraphicsContext,
        rect: CGRect
    ) {
        context.fill(
            Path(stroke.cgPath(in: rect)),
            with: .color(Color.royalBlueAccent.opacity(0.12))
        )
        context.stroke(
            Path(stroke.medianPath(in: rect)),
            with: .color(
                isValidationError
                    ? Color.roseAccent.opacity(0.65)
                    : Color.royalBlueAccent.opacity(0.55)
            ),
            style: StrokeStyle(lineWidth: 3, dash: [7, 5])
        )
        renderStartMarker(stroke, in: &context, rect: rect)
    }

    private func renderStartMarker(
        _ stroke: StrokeOrderStroke,
        in context: inout GraphicsContext,
        rect: CGRect
    ) {
        guard let start = stroke.median.first else { return }
        let point = start.cgPoint(in: rect)
        let marker = Path(
            ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
        )
        context.fill(marker, with: .color(Color.roseAccent))
    }

    private func renderUserStroke(
        _ points: [CGPoint],
        in context: inout GraphicsContext
    ) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(
            path,
            with: .color(Color.darkForeground),
            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
        )
    }

    private func appendPoint(_ point: CGPoint) {
        guard !isAnimating, !isCharacterComplete, !isAdvancingStroke else {
            return
        }
        currentLine.append(point)
    }

    private func finishStroke(at point: CGPoint, in rect: CGRect) {
        appendPoint(point)
        guard !currentLine.isEmpty,
            !isAnimating,
            !isCharacterComplete,
            !isAdvancingStroke,
            let currentData,
            currentData.strokes.indices.contains(strokeIndex)
        else {
            return
        }

        let result = validator.validate(
            points: currentLine,
            for: currentData.strokes[strokeIndex],
            in: rect
        )

        switch result {
        case .accepted:
            acceptCurrentStroke(in: currentData)
        case .rejected(let failure):
            rejectCurrentStroke(failure)
        }
    }

    private func acceptCurrentStroke(in character: StrokeOrderCharacter) {
        transitionTask?.cancel()
        validationFeedbackTask?.cancel()
        validationMessage = nil
        isValidationError = false
        drawnStrokes.append(currentLine)
        currentLine = []
        isAdvancingStroke = true

        transitionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(240))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            isAdvancingStroke = false

            if strokeIndex + 1 == character.strokes.count {
                isCharacterComplete = true
            } else {
                strokeIndex += 1
            }
        }
    }

    private func rejectCurrentStroke(
        _ failure: StrokeOrderStrokeValidator.Failure
    ) {
        transitionTask?.cancel()
        currentLine = []
        validationMessage = failure.coachingMessage
        isValidationError = true
        HapticManager.shared.impact(style: .light)

        validationFeedbackTask?.cancel()
        validationFeedbackTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(1_200))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            validationMessage = nil
            isValidationError = false
        }
    }

    private func clearCurrentStroke() {
        guard !isAnimating, !isAdvancingStroke else { return }
        currentLine = []
        validationFeedbackTask?.cancel()
        validationMessage = nil
        isValidationError = false
    }

    private func replay() {
        guard currentData != nil else { return }
        resetCharacter()
        startAnimation()
    }

    private func startAnimation() {
        guard let currentData else { return }
        animationTask?.cancel()
        isAnimating = false
        animationStrokeIndex = 0
        animationProgress = 0

        guard !reduceMotion else { return }

        isAnimating = true
        animationTask = Task { @MainActor in
            for index in currentData.strokes.indices {
                guard !Task.isCancelled else { return }
                animationStrokeIndex = index
                animationProgress = 0
                withAnimation(.easeInOut(duration: 0.55)) {
                    animationProgress = 1
                }

                do {
                    try await Task.sleep(for: .milliseconds(700))
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            isAnimating = false
            animationStrokeIndex = 0
            animationProgress = 0
        }
    }

    private func resetCharacter() {
        animationTask?.cancel()
        transitionTask?.cancel()
        validationFeedbackTask?.cancel()
        drawnStrokes = []
        currentLine = []
        isCharacterComplete = false
        isAdvancingStroke = false
        validationMessage = nil
        isValidationError = false
        strokeIndex = 0
        isAnimating = false
        animationStrokeIndex = 0
        animationProgress = 0
    }

    private func advanceCharacter() {
        guard !isLastCharacter else {
            dismiss()
            return
        }
        characterIndex += 1
        resetCharacter()
        startAnimation()
    }

    private var characterNavigationButton: some View {
        Button(action: advanceCharacter) {
            Text(isLastCharacter ? "Done" : "Next Character")
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(
                        isLastCharacter
                            ? Color.tealAccent
                            : Color.royalBlueAccent
                    )
                )
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier(
            isLastCharacter
                ? "stroke-order-done"
                : "stroke-order-next-character"
        )
    }

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 42))
                .foregroundStyle(Color.darkForeground.opacity(0.4))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.darkForeground.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            Color.warmIvoryCard,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func canvasAccessibilityLabel(
        for character: StrokeOrderCharacter
    ) -> String {
        if isAnimating {
            return "Animating \(character.character) stroke order"
        }
        if let validationMessage {
            return "Stroke rejected. \(validationMessage)"
        }
        if isAdvancingStroke {
            return "Stroke accepted. Advancing to the next stroke"
        }
        if isCharacterComplete {
            return "Completed \(character.character)"
        }
        return "Trace stroke \(strokeIndex + 1) of \(character.strokes.count) for \(character.character)"
    }
}

#Preview {
    NavigationStack {
        StrokeOrderLessonView(word: "你好")
    }
}
