import SwiftUI
import UIKit

struct HandwritingCanvasView: View {
    let onSelectCandidate: (String) -> Void
    let onClearQuery: () -> Void
    let onBackspace: () -> Void

    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var candidates: [String] = []
    @State private var isRecognizing = false
    @State private var recognitionTask: Task<Void, Never>?

    private let canvasHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Candidate Suggestion Bar
            HStack(spacing: 8) {
                if candidates.isEmpty {
                    Text(isRecognizing ? "Recognizing..." : "Draw a Chinese character below...")
                        .font(.subheadline)
                        .foregroundColor(Color.darkForeground.opacity(0.5))
                        .padding(.leading, 12)
                    Spacer()
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
                                        .foregroundColor(Color.royalBlueAccent)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.royalBlueAccent.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }

                HStack(spacing: 6) {
                    Button(action: onBackspace) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.darkForeground.opacity(0.7))
                            .padding(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: clearCanvas) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(lines.isEmpty && currentLine.isEmpty)
                }
                .padding(.trailing, 8)
            }
            .frame(height: 46)
            .background(Color.warmIvoryCard)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.black.opacity(0.08)),
                alignment: .bottom
            )

            // Drawing Pad Area
            ZStack {
                Color.warmIvoryCard

                // Canvas Grid guide lines
                GeometryReader { geo in
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: w / 2, y: 0))
                        path.addLine(to: CGPoint(x: w / 2, y: h))
                        path.move(to: CGPoint(x: 0, y: h / 2))
                        path.addLine(to: CGPoint(x: w, y: h / 2))
                    }
                    .stroke(Color.royalBlueAccent.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                Canvas { context, size in
                    for line in lines {
                        var path = Path()
                        if let first = line.first {
                            path.move(to: first)
                            for pt in line.dropFirst() {
                                path.addLine(to: pt)
                            }
                        }
                        context.stroke(
                            path,
                            with: .color(Color.darkForeground),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                        )
                    }

                    var currentPath = Path()
                    if let first = currentLine.first {
                        currentPath.move(to: first)
                        for pt in currentLine.dropFirst() {
                            currentPath.addLine(to: pt)
                        }
                    }
                    context.stroke(
                        currentPath,
                        with: .color(Color.darkForeground),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentLine.append(value.location)
                        }
                        .onEnded { value in
                            lines.append(currentLine)
                            currentLine = []
                            scheduleRecognition()
                        }
                )
            }
            .frame(height: canvasHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.creamBackground)
    }

    private func clearCanvas() {
        recognitionTask?.cancel()
        lines = []
        currentLine = []
        candidates = []
        isRecognizing = false
    }

    private func scheduleRecognition() {
        recognitionTask?.cancel()
        guard !lines.isEmpty else { return }

        let allLines = lines
        recognitionTask = Task {
            isRecognizing = true
            let image = renderImage(from: allLines, size: CGSize(width: 300, height: 200))
            let recognized = await ChineseHandwritingRecognizer.shared.recognize(image: image)
            guard !Task.isCancelled else { return }
            candidates = recognized
            isRecognizing = false
        }
    }

    private func renderImage(from lines: [[CGPoint]], size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let path = UIBezierPath()
            path.lineWidth = 8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            for line in lines {
                if let first = line.first {
                    path.move(to: first)
                    for pt in line.dropFirst() {
                        path.addLine(to: pt)
                    }
                }
            }

            UIColor.black.setStroke()
            path.stroke()
        }
    }
}
