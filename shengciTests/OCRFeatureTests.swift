import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import shengci

private actor TestChineseLexicon: ChineseLexicon {
  private let entriesByTerm: [String: [CEDICTEntry]]

  init(entriesByTerm: [String: [CEDICTEntry]]) {
    self.entriesByTerm = entriesByTerm
  }

  func exactEntries(
    for terms: Set<String>
  ) async -> [String: [CEDICTEntry]] {
    Dictionary(
      uniqueKeysWithValues: terms.map {
        ($0, entriesByTerm[$0] ?? [])
      }
    )
  }
}

private actor TestOCRRecognizer: OCRRecognizing {
  private let result: Result<[OCRTextRegion], Error>

  init(result: Result<[OCRTextRegion], Error>) {
    self.result = result
  }

  func recognizeChineseText(
    in imageData: Data
  ) async throws -> [OCRTextRegion] {
    try result.get()
  }
}

private actor DelayedOCRRecognizer: OCRRecognizing {
  private let region: OCRTextRegion

  init(region: OCRTextRegion) {
    self.region = region
  }

  func recognizeChineseText(
    in imageData: Data
  ) async throws -> [OCRTextRegion] {
    try await Task.sleep(for: .seconds(1))
    return [region]
  }
}

struct OCRFeatureTests {
  @Test func configuresBothChineseRecognitionSystems() {
    #expect(
      AppleOCRRecognizer.preferredLanguages == ["zh-Hans", "zh-Hant"]
    )
  }

  @Test func mapsImageOrientationMetadata() {
    #expect(OCRImageOrientation.value(from: nil) == .up)
    #expect(OCRImageOrientation.value(from: 6) == .right)
    #expect(OCRImageOrientation.value(from: 8) == .left)
  }

  @Test func keepsOnlyChineseRuns() {
    #expect(ChineseText.sanitized("Hello 你好，世界! 123") == "你好 世界")
    #expect(ChineseText.runs(in: "學習中文 OCR") == ["學習中文"])
    #expect(ChineseText.characters(in: "A你1好") == ["你", "好"])
  }

  @Test func mapsVisionCoordinatesIntoAspectFitImage() {
    let layout = OCRImageLayout(
      imageSize: CGSize(width: 200, height: 100),
      containerSize: CGSize(width: 300, height: 300)
    )

    #expect(layout.imageFrame == CGRect(x: 0, y: 75, width: 300, height: 150))
    #expect(
      layout.viewRect(
        for: CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
      ) == CGRect(x: 75, y: 112.5, width: 150, height: 37.5)
    )
  }

  @Test func segmentsLongestWordsAndFallsBackToCharacters() async {
    let entries = [
      Self.makeEntry(id: 1, simplified: "我"),
      Self.makeEntry(id: 2, simplified: "喜欢"),
      Self.makeEntry(id: 3, simplified: "学习"),
      Self.makeEntry(id: 4, simplified: "学习中文"),
    ]
    let lexicon = TestChineseLexicon(
      entriesByTerm: Dictionary(
        uniqueKeysWithValues: entries.map { ($0.simplified, [$0]) }
      )
    )
    let segmenter = ChineseTextSegmenter(lexicon: lexicon)

    let tokens = await segmenter.segment(
      "我喜欢学习中文呀",
      mode: .words
    )

    #expect(tokens.map(\.text) == ["我", "喜欢", "学习中文", "呀"])
    #expect(tokens.last?.entries.isEmpty == true)
  }

  @Test func supportsTraditionalTermsAndCharacterCorrection() async {
    let entry = CEDICTEntry(
      id: 1,
      traditional: "學習",
      simplified: "学习",
      pinyin: "xue2 xi2",
      definitions: ["to study"]
    )
    let lexicon = TestChineseLexicon(entriesByTerm: ["學習": [entry]])
    let segmenter = ChineseTextSegmenter(lexicon: lexicon)

    let wordTokens = await segmenter.segment("學習。", mode: .words)
    let characterTokens = await segmenter.segment(
      "學習。",
      mode: .characters
    )

    #expect(wordTokens.map(\.text) == ["學習"])
    #expect(characterTokens.map(\.text) == ["學", "習"])
  }

  @Test func limitsAutomaticWordsToEightCharacters() async {
    let nineCharacterTerm = "一二三四五六七八九"
    let entry = Self.makeEntry(id: 1, simplified: nineCharacterTerm)
    let lexicon = TestChineseLexicon(
      entriesByTerm: [nineCharacterTerm: [entry]]
    )
    let segmenter = ChineseTextSegmenter(lexicon: lexicon)

    let tokens = await segmenter.segment(nineCharacterTerm, mode: .words)

    #expect(tokens.map(\.text) == ChineseText.characters(in: nineCharacterTerm))
  }

  @Test func batchesSimplifiedAndTraditionalExactLookups() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = CEDICTEntry(
      id: 1,
      traditional: "學習",
      simplified: "学习",
      pinyin: "xue2 xi2",
      definitions: ["to study"]
    )
    let store = CEDICTStore(
      databaseDirectory: directory,
      loader: { [entry] }
    )

    try await store.prepare()
    let results = await store.exactEntries(
      for: ["学习", "學習", "不存在"]
    )

    #expect(results["学习"] == [entry])
    #expect(results["學習"] == [entry])
    #expect(results["不存在"]?.isEmpty == true)
  }

  @Test @MainActor func scanModelHandlesSuccessAndInvalidImages() async throws {
    let region = OCRTextRegion(
      id: 0,
      transcript: "你好",
      boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
      confidence: 0.9
    )
    let recognizer = TestOCRRecognizer(result: .success([region]))
    let model = ScanViewModel(recognizer: recognizer)
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: 2, height: 2)
    )
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    guard let imageData = image.pngData() else {
      throw OCRRecognitionError.imageDecodingFailed
    }

    await model.importPhotoData(imageData)
    #expect(model.phase == .photoReady)
    #expect(model.regions == [region])

    await model.importPhotoData(Data("not an image".utf8))
    guard case .failed = model.phase else {
      Issue.record("Expected invalid image data to produce a failed state")
      return
    }

    await model.importPhotoData(imageData)
    #expect(model.phase == .photoReady)
  }

  @Test @MainActor func resetCancelsPhotoRecognition() async throws {
    let region = OCRTextRegion(
      id: 0,
      transcript: "你好",
      boundingBox: .zero,
      confidence: 1
    )
    let model = ScanViewModel(
      recognizer: DelayedOCRRecognizer(region: region)
    )
    let imageData = try Self.makeImageData()

    model.startPhotoRecognition(imageData)
    await Task.yield()
    #expect(model.phase == .recognizingPhoto)

    model.resetSession()
    try await Task.sleep(for: .milliseconds(50))

    #expect(model.phase == .checkingCamera)
    #expect(model.regions.isEmpty)
  }

  private static func makeEntry(
    id: Int,
    simplified: String
  ) -> CEDICTEntry {
    CEDICTEntry(
      id: id,
      traditional: simplified,
      simplified: simplified,
      pinyin: "test1",
      definitions: ["test"]
    )
  }

  private static func makeImageData() throws -> Data {
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: 2, height: 2)
    )
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    guard let data = image.pngData() else {
      throw OCRRecognitionError.imageDecodingFailed
    }
    return data
  }
}
