import ImageIO

nonisolated enum OCRImageOrientation {
  static func value(
    from rawValue: UInt32?
  ) -> CGImagePropertyOrientation {
    guard
      let rawValue,
      let orientation = CGImagePropertyOrientation(rawValue: rawValue)
    else {
      return .up
    }
    return orientation
  }
}
