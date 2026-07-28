enum ScanPhase: Equatable {
  case checkingCamera
  case cameraPrompt
  case requestingCamera
  case cameraReady
  case cameraUnavailable(ScanCameraIssue)
  case loadingPhoto
  case recognizingPhoto
  case photoReady
  case failed(String)
}
