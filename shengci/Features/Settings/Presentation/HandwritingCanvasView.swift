import SwiftUI

struct HandwritingCanvasView: View {
    let recognizer: any ChineseHandwritingRecognizing
    let onSelectCandidate: (String) -> Void

    @State private var lines: [HandwritingStroke] = []
    @State private var currentLine: HandwritingStroke = []
    @State private var candidates: [String] = []
    @State private var recognitionTask: Task<Void, Never>?
    @State private var preparationTask: Task<Void, Never>?
    @State private var state: DrawingState = .preparing
    @State private var canvasSize = CGSize(width: 1, height: 200)

    private let canvasHeight: CGFloat = 200

    init(
        recognizer: any ChineseHandwritingRecognizing,
        onSelectCandidate: @escaping (String) -> Void
    ) {
        self.recognizer = recognizer
        self.onSelectCandidate = onSelectCandidate
    }

    var body: some View {
        VStack(spacing: 0) {
            candidateBar
            canvas
        }
        .background(Color.creamBackground)
        .task { prepareRecognizer() }
        .onDisappear { cancelAndClear() }
    }

    @ViewBuilder
    private var candidateBar: some View {
        HStack(spacing: 8) {
            switch state {
            case .preparing:
                ProgressView()
                    .controlSize(.small)
                Text("Preparing handwriting…")
                    .foregroundStyle(Color.darkForeground.opacity(0.55))
            case .failed(let message):
                Text(message)
                    .lineLimit(1)
                    .foregroundStyle(Color.darkForeground.opacity(0.7))
                Button("Retry", action: prepareRecognizer)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.royalBlueAccent)
            case .ready:
                if candidates.isEmpty {
                    Text(recognitionTask == nil ? "Draw a Chinese character below" : "Recognizing…")
                        .foregroundStyle(Color.darkForeground.opacity(0.5))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(candidates, id: \.self) { candidate in
                                Button {
                                    onSelectCandidate(candidate)
                                    clearCanvas()
                                } label: {
                                    Text(candidate)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .foregroundStyle(Color.royalBlueAccent)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.royalBlueAccent.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use \(candidate)")
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: clearCanvas) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .disabled(lines.isEmpty && currentLine.isEmpty)
            .accessibilityLabel("Clear drawing")
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.warmIvoryCard)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
        }
    }

    private var canvas: some View {
        ZStack {
            Color.warmIvoryCard
            guideLines
            GeometryReader { geometry in
                Canvas { context, _ in
                    draw(lines, in: &context)
                    draw([currentLine], in: &context)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in append(point: value.location) }
                        .onEnded { value in finishStroke(at: value.location) }
                )
                .allowsHitTesting(state == .ready)
                .onAppear { canvasSize = geometry.size }
                .onChange(of: geometry.size) { canvasSize = $0 }
            }
        }
        .frame(height: canvasHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var guideLines: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height))
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.royalBlueAccent.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    private func draw(_ strokes: [HandwritingStroke], in context: inout GraphicsContext) {
        for stroke in strokes where !stroke.isEmpty {
            var path = Path()
            path.move(to: CGPoint(x: stroke[0].x, y: stroke[0].y))
            for point in stroke.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.stroke(
                path,
                with: .color(Color.darkForeground),
                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func append(point: CGPoint) {
        guard state == .ready else { return }
        currentLine.append(
            HandwritingPoint(
                x: point.x,
                y: point.y,
                timestampMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1_000)
            )
        )
    }

    private func finishStroke(at point: CGPoint) {
        append(point: point)
        guard !currentLine.isEmpty else { return }
        lines.append(currentLine)
        currentLine = []
        recognizeCurrentDrawing()
    }

    private func prepareRecognizer() {
        preparationTask?.cancel()
        state = .preparing
        preparationTask = Task {
            do {
                try await recognizer.prepare()
                guard !Task.isCancelled else { return }
                state = .ready
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func recognizeCurrentDrawing() {
        recognitionTask?.cancel()
        let capturedLines = lines
        recognitionTask = Task {
            do {
                let recognized = try await recognizer.recognize(
                    strokes: capturedLines,
                    writingArea: canvasSize
                )
                guard !Task.isCancelled else { return }
                candidates = recognized
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                candidates = []
            }
            recognitionTask = nil
        }
    }

    private func clearCanvas() {
        recognitionTask?.cancel()
        lines = []
        currentLine = []
        candidates = []
        recognitionTask = nil
    }

    private func cancelAndClear() {
        preparationTask?.cancel()
        clearCanvas()
    }

    private enum DrawingState: Equatable {
        case preparing
        case ready
        case failed(String)
    }
}
