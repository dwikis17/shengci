import PhotosUI
import SwiftUI

struct ScanView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @State private var model: ScanViewModel
  @State private var selectedPhoto: PhotosPickerItem?

  init(recognizer: any OCRRecognizing = AppleOCRRecognizer()) {
    _model = State(
      initialValue: ScanViewModel(recognizer: recognizer)
    )
  }

  var body: some View {
    @Bindable var model = model

    NavigationStack {
      ZStack {
        Color.creamBackground.ignoresSafeArea()
        scanContent
      }
      .navigationTitle("Scan")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(Color.creamBackground, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if model.photoImage != nil {
            Button(
              "Live Camera",
              systemImage: "camera.fill",
              action: model.showCamera
            )
            .labelStyle(.iconOnly)
          }

          PhotosPicker(
            selection: $selectedPhoto,
            matching: .images
          ) {
            Label("Choose Photo", systemImage: "photo")
          }
          .labelStyle(.iconOnly)
        }
      }
    }
    .sheet(item: $model.selectedText) { selection in
      ScannedTextSheet(selection: selection)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .task {
      model.prepareCamera()
    }
    .onChange(of: selectedPhoto) { _, item in
      guard let item else { return }
      model.selectPhoto(item)
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active, model.phase == .checkingCamera {
        model.prepareCamera()
      }
    }
    .onDisappear(perform: model.resetSession)
  }

  @ViewBuilder
  private var scanContent: some View {
    switch model.phase {
    case .checkingCamera:
      ProgressView("Checking camera…")

    case .cameraPrompt:
      ContentUnavailableView {
        Label("Scan Chinese Text", systemImage: "viewfinder")
      } description: {
        Text(
          "Use the camera to tap Chinese text and look it up instantly."
        )
      } actions: {
        Button(
          "Start Camera",
          systemImage: "camera.fill",
          action: model.requestCameraAccess
        )
        .buttonStyle(.borderedProminent)
        .tint(Color.royalBlueAccent)
      }

    case .requestingCamera:
      ProgressView("Requesting camera access…")

    case .cameraReady:
      ZStack(alignment: .bottom) {
        LiveTextScannerView(
          isScanning: scenePhase == .active
            && model.selectedText == nil,
          onSelectText: model.selectTranscript,
          onUnavailable: model.scannerDidBecomeUnavailable
        )
        .ignoresSafeArea(edges: .bottom)

        Text("Tap highlighted Chinese text")
          .font(.subheadline.bold())
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(.ultraThinMaterial, in: Capsule())
          .padding(.bottom)
      }

    case .cameraUnavailable(let issue):
      ContentUnavailableView {
        Label(issue.title, systemImage: "camera.fill")
      } description: {
        Text(issue.message)
      } actions: {
        if issue == .denied {
          Button(
            "Open Settings",
            systemImage: "gearshape",
            action: openAppSettings
          )
          .buttonStyle(.borderedProminent)
          .tint(Color.royalBlueAccent)
        }
      }

    case .loadingPhoto:
      ProgressView("Loading photo…")

    case .recognizingPhoto:
      ProgressView("Recognizing Chinese text…")

    case .photoReady:
      if let image = model.photoImage {
        PhotoOCRView(
          image: image,
          regions: model.regions,
          onSelectRegion: selectRegion
        )
      }

    case .failed(let message):
      ContentUnavailableView {
        Label("Couldn’t Scan Image", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      } actions: {
        Button(
          "Return to Camera",
          systemImage: "camera.fill",
          action: model.showCamera
        )
        .buttonStyle(.borderedProminent)
        .tint(Color.royalBlueAccent)
      }
    }
  }

  private func selectRegion(_ region: OCRTextRegion) {
    model.selectTranscript(region.transcript)
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    openURL(url)
  }
}
