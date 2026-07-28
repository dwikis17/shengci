import SwiftUI
import VisionKit

struct LiveTextScannerView: UIViewControllerRepresentable {
  let isScanning: Bool
  let onSelectText: (String) -> Void
  let onUnavailable: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      onSelectText: onSelectText,
      onUnavailable: onUnavailable
    )
  }

  func makeUIViewController(
    context: Context
  ) -> DataScannerViewController {
    let chineseLanguages = DataScannerViewController
      .supportedTextRecognitionLanguages
      .filter { $0.lowercased().hasPrefix("zh") }
    let scanner = DataScannerViewController(
      recognizedDataTypes: [
        .text(languages: chineseLanguages),
      ],
      qualityLevel: .balanced,
      recognizesMultipleItems: true,
      isHighFrameRateTrackingEnabled: true,
      isPinchToZoomEnabled: true,
      isGuidanceEnabled: true,
      isHighlightingEnabled: true
    )
    scanner.delegate = context.coordinator
    updateScanningState(for: scanner)
    return scanner
  }

  func updateUIViewController(
    _ scanner: DataScannerViewController,
    context: Context
  ) {
    context.coordinator.onSelectText = onSelectText
    context.coordinator.onUnavailable = onUnavailable
    updateScanningState(for: scanner)
  }

  static func dismantleUIViewController(
    _ scanner: DataScannerViewController,
    coordinator: Coordinator
  ) {
    scanner.stopScanning()
    scanner.delegate = nil
  }

  private func updateScanningState(
    for scanner: DataScannerViewController
  ) {
    if isScanning, !scanner.isScanning {
      do {
        try scanner.startScanning()
      } catch {
        Task { @MainActor in
          onUnavailable()
        }
      }
    } else if !isScanning, scanner.isScanning {
      scanner.stopScanning()
    }
  }

  @MainActor
  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    var onSelectText: (String) -> Void
    var onUnavailable: () -> Void

    init(
      onSelectText: @escaping (String) -> Void,
      onUnavailable: @escaping () -> Void
    ) {
      self.onSelectText = onSelectText
      self.onUnavailable = onUnavailable
    }

    func dataScanner(
      _ dataScanner: DataScannerViewController,
      didTapOn item: RecognizedItem
    ) {
      guard case .text(let text) = item else { return }
      let transcript = ChineseText.sanitized(text.transcript)
      guard !transcript.isEmpty else { return }
      onSelectText(transcript)
    }

    func dataScanner(
      _ dataScanner: DataScannerViewController,
      becameUnavailableWithError error:
        DataScannerViewController.ScanningUnavailable
    ) {
      onUnavailable()
    }
  }
}
