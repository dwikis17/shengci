import CoreGraphics

nonisolated struct OCRImageLayout {
  let imageFrame: CGRect

  init(imageSize: CGSize, containerSize: CGSize) {
    guard
      imageSize.width > 0,
      imageSize.height > 0,
      containerSize.width > 0,
      containerSize.height > 0
    else {
      imageFrame = .zero
      return
    }

    let scale = min(
      containerSize.width / imageSize.width,
      containerSize.height / imageSize.height
    )
    let fittedSize = CGSize(
      width: imageSize.width * scale,
      height: imageSize.height * scale
    )
    imageFrame = CGRect(
      x: (containerSize.width - fittedSize.width) / 2,
      y: (containerSize.height - fittedSize.height) / 2,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  func viewRect(for visionBoundingBox: CGRect) -> CGRect {
    CGRect(
      x: imageFrame.minX
        + (visionBoundingBox.minX * imageFrame.width),
      y: imageFrame.minY
        + ((1 - visionBoundingBox.maxY) * imageFrame.height),
      width: visionBoundingBox.width * imageFrame.width,
      height: visionBoundingBox.height * imageFrame.height
    )
  }
}
