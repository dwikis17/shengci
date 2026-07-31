import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.creamBackground
                .ignoresSafeArea()

            Circle()
                .fill(Color.royalBlueAccent.opacity(0.09))
                .frame(width: 420, height: 420)
                .blur(radius: 2)
                .offset(x: 150, y: -300)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                characterStack

                Spacer(minLength: 36)

                VStack(spacing: 14) {
                    Text("Chinese, one word\nat a time.")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(Color.darkForeground)
                        .multilineTextAlignment(.center)

                    Text("Build your vocabulary with daily words, quick scans, and focused practice.")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.darkForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 32)

                Button(action: onContinue) {
                    HStack {
                        Text("Start learning")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 58)
                    .background(Color.royalBlueAccent, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the learning screen")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private var characterStack: some View {
        ZStack {
            characterCard("学", color: Color.tealAccent, rotation: -10, offset: -88)
            characterCard("词", color: Color.roseAccent, rotation: 10, offset: 88)
            characterCard("生", color: Color.royalBlueAccent, rotation: 0, offset: 0)
        }
        .frame(height: 250)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Chinese characters for Shengci")
    }

    private func characterCard(
        _ character: String,
        color: Color,
        rotation: Double,
        offset: CGFloat
    ) -> some View {
        Text(character)
            .font(.system(size: 82, weight: .bold, design: .serif))
            .foregroundStyle(color)
            .frame(width: 150, height: 190)
            .background(Color.warmIvoryCard, in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: color.opacity(0.14), radius: 20, y: 12)
            .rotationEffect(.degrees(rotation))
            .offset(x: offset)
    }
}

#Preview {
    OnboardingView {}
}
