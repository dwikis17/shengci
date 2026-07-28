import AVFoundation
import Observation
import PhotosUI
import SwiftUI
import VisionKit

@MainActor
@Observable
final class ScanViewModel {
  private(set) var phase = ScanPhase.checkingCamera
  private(set) var photoImage: UIImage?
  private(set) var regions: [OCRTextRegion] = []
  var selectedText: ScannedTextSelection?

  @ObservationIgnored private let recognizer: any OCRRecognizing
  @ObservationIgnored private var recognitionTask: Task<Void, Never>?

  init(recognizer: any OCRRecognizing = AppleOCRRecognizer()) {
    self.recognizer = recognizer
  }

  func prepareCamera() {
    guard photoImage == nil else { return }
    guard DataScannerViewController.isSupported else {
      phase = .cameraUnavailable(.unsupported)
      return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      phase = DataScannerViewController.isAvailable
        ? .cameraReady
        : .cameraUnavailable(.unavailable)
    case .notDetermined:
      phase = .cameraPrompt
    case .denied:
      phase = .cameraUnavailable(.denied)
    case .restricted:
      phase = .cameraUnavailable(.restricted)
    @unknown default:
      phase = .cameraUnavailable(.unavailable)
    }
  }

  func requestCameraAccess() {
    guard phase == .cameraPrompt else { return }
    phase = .requestingCamera

    Task {
      _ = await AVCaptureDevice.requestAccess(for: .video)
      guard !Task.isCancelled else { return }
      prepareCamera()
    }
  }

  func selectPhoto(_ item: PhotosPickerItem) {
    recognitionTask?.cancel()
    phase = .loadingPhoto
    selectedText = nil

    recognitionTask = Task {
      do {
        guard let data = try await item.loadTransferable(type: Data.self) else {
          throw OCRRecognitionError.imageDecodingFailed
        }
        try Task.checkCancellation()
        await importPhotoData(data)
      } catch is CancellationError {
        return
      } catch {
        phase = .failed(error.localizedDescription)
      }
    }
  }

  func importPhotoData(_ data: Data) async {
    guard let image = UIImage(data: data) else {
      phase = .failed(OCRRecognitionError.imageDecodingFailed.localizedDescription)
      return
    }

    photoImage = image
    regions = []
    phase = .recognizingPhoto

    do {
      let recognizedRegions = try await recognizer.recognizeChineseText(
        in: data
      )
      try Task.checkCancellation()
      regions = recognizedRegions
      phase = .photoReady
    } catch is CancellationError {
      return
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  func startPhotoRecognition(_ data: Data) {
    recognitionTask?.cancel()
    recognitionTask = Task {
      await importPhotoData(data)
    }
  }

  func selectTranscript(_ transcript: String) {
    let sanitizedTranscript = ChineseText.sanitized(transcript)
    guard !sanitizedTranscript.isEmpty else { return }
    selectedText = ScannedTextSelection(transcript: sanitizedTranscript)
  }

  func showCamera() {
    recognitionTask?.cancel()
    photoImage = nil
    regions = []
    selectedText = nil
    phase = .checkingCamera
    prepareCamera()
  }

  func scannerDidBecomeUnavailable() {
    phase = .cameraUnavailable(.unavailable)
  }

  func resetSession() {
    recognitionTask?.cancel()
    recognitionTask = nil
    photoImage = nil
    regions = []
    selectedText = nil
    phase = .checkingCamera
  }
}
