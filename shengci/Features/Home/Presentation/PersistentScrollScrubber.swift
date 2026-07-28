import SwiftUI

struct PersistentScrollScrubber: View {
    let progress: Double
    let previewCharacter: String
    let position: Int
    let total: Int
    let onScrub: (_ progress: Double, _ isFinal: Bool) -> Void

    @State private var isScrubbing = false
    @State private var feedbackBucket = 0

    private let thumbHeight = 48.0

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(geometry.size.height - thumbHeight, 1)
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.darkForeground.opacity(0.14))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, thumbHeight / 2)

                Capsule()
                    .fill(Color.royalBlueAccent)
                    .frame(width: isScrubbing ? 12 : 8, height: thumbHeight)
                    .shadow(
                        color: Color.black.opacity(isScrubbing ? 0.16 : 0.08),
                        radius: isScrubbing ? 6 : 2,
                        y: 1
                    )
                    .offset(y: clampedProgress * availableHeight)

                if isScrubbing {
                    scrubPreview
                        .offset(
                            x: -82,
                            y: min(
                                max(
                                    clampedProgress * availableHeight - 16,
                                    0
                                ),
                                max(geometry.size.height - 72, 0)
                            )
                        )
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        updateScrub(
                            locationY: value.location.y,
                            availableHeight: availableHeight,
                            isFinal: false
                        )
                    }
                    .onEnded { value in
                        updateScrub(
                            locationY: value.location.y,
                            availableHeight: availableHeight,
                            isFinal: true
                        )
                        isScrubbing = false
                    }
            )
        }
        .frame(width: 44)
        .sensoryFeedback(.selection, trigger: feedbackBucket)
        .accessibilityElement()
        .accessibilityLabel("Word list scroll position")
        .accessibilityValue("\(position) of \(total)")
        .accessibilityHint("Swipe up or down to move quickly through words")
        .accessibilityAdjustableAction { direction in
            let step = total > 1 ? 10.0 / Double(total - 1) : 1
            let targetProgress: Double

            switch direction {
            case .increment:
                targetProgress = min(progress + step, 1)
            case .decrement:
                targetProgress = max(progress - step, 0)
            @unknown default:
                return
            }

            onScrub(targetProgress, true)
        }
    }

    private var scrubPreview: some View {
        VStack(spacing: 2) {
            Text(previewCharacter)
                .font(.title2.bold())
                .fontDesign(.serif)

            Text("\(position) / \(total)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(Color.darkForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 72)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.08))
        }
        .allowsHitTesting(false)
    }

    private func updateScrub(
        locationY: Double,
        availableHeight: Double,
        isFinal: Bool
    ) {
        let adjustedLocation = locationY - thumbHeight / 2
        let newProgress = min(max(adjustedLocation / availableHeight, 0), 1)
        feedbackBucket = Int((newProgress * 20).rounded())
        onScrub(newProgress, isFinal)
    }
}
