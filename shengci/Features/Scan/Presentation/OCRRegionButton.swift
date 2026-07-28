import SwiftUI

struct OCRRegionButton: View {
  let region: OCRTextRegion
  let frame: CGRect
  let action: (OCRTextRegion) -> Void

  var body: some View {
    Button {
      action(region)
    } label: {
      Color.clear
        .frame(
          width: max(frame.width, 44),
          height: max(frame.height, 44)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.amberAccent.opacity(0.16))
            .stroke(Color.amberAccent, lineWidth: 2)
            .frame(
              width: max(frame.width, 2),
              height: max(frame.height, 2)
            )
        }
    }
    .buttonStyle(.plain)
    .position(x: frame.midX, y: frame.midY)
    .accessibilityLabel("Look up \(region.transcript)")
    .accessibilityInputLabels([region.transcript, "Look up text"])
  }
}
