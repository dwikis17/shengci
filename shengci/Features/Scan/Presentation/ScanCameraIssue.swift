enum ScanCameraIssue: Equatable {
  case denied
  case restricted
  case unavailable
  case unsupported

  var title: String {
    switch self {
    case .denied:
      "Camera Access Denied"
    case .restricted:
      "Camera Restricted"
    case .unavailable:
      "Camera Unavailable"
    case .unsupported:
      "Live Scan Unavailable"
    }
  }

  var message: String {
    switch self {
    case .denied:
      "Allow camera access in Settings, or choose a photo instead."
    case .restricted:
      "Camera access is restricted on this device. You can still choose a photo."
    case .unavailable:
      "The camera cannot start right now. You can still choose a photo."
    case .unsupported:
      "This device does not support live text scanning. Choose a photo to use OCR."
    }
  }
}
