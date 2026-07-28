import SwiftUI

struct ZoomableOCRImageView: View {
  let image: UIImage
  let regions: [OCRTextRegion]
  let onSelectRegion: (OCRTextRegion) -> Void

  @State private var scale = 1.0
  @State private var settledScale = 1.0
  @State private var offset = CGSize.zero
  @State private var settledOffset = CGSize.zero

  var body: some View {
    GeometryReader { geometry in
      let layout = OCRImageLayout(
        imageSize: image.size,
        containerSize: geometry.size
      )

      ZStack(alignment: .topLeading) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(
            width: layout.imageFrame.width,
            height: layout.imageFrame.height
          )
          .position(
            x: layout.imageFrame.midX,
            y: layout.imageFrame.midY
          )
          .accessibilityLabel("Selected image with recognized Chinese text")

        ForEach(regions) { region in
          OCRRegionButton(
            region: region,
            frame: layout.viewRect(for: region.boundingBox),
            action: onSelectRegion
          )
        }
      }
      .scaleEffect(scale)
      .offset(offset)
      .contentShape(.rect)
      .gesture(magnifyGesture)
      .simultaneousGesture(dragGesture)
    }
    .background(Color.black.opacity(0.04))
    .clipShape(.rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    }
  }

  private var magnifyGesture: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        scale = min(max(settledScale * value.magnification, 1), 5)
      }
      .onEnded { _ in
        settledScale = scale
        if scale == 1 {
          offset = .zero
          settledOffset = .zero
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        guard scale > 1 else { return }
        offset = CGSize(
          width: settledOffset.width + value.translation.width,
          height: settledOffset.height + value.translation.height
        )
      }
      .onEnded { _ in
        settledOffset = offset
      }
  }
}
