import SwiftUI

struct PhotoOCRView: View {
  let image: UIImage
  let regions: [OCRTextRegion]
  let onSelectRegion: (OCRTextRegion) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ZoomableOCRImageView(
        image: image,
        regions: regions,
        onSelectRegion: onSelectRegion
      )
      .frame(maxHeight: .infinity)

      Text("Detected Text")
        .font(.headline)
        .foregroundStyle(Color.darkForeground)

      ScrollView(.horizontal) {
        LazyHStack(spacing: 10) {
          ForEach(regions) { region in
            Button(region.transcript) {
              onSelectRegion(region)
            }
            .buttonStyle(.bordered)
            .tint(Color.royalBlueAccent)
            .accessibilityHint("Opens dictionary word selection")
          }
        }
      }
      .scrollIndicators(.hidden)
      .frame(minHeight: 44)
    }
    .padding()
  }
}
