import CoreGraphics
import Foundation
import Testing
@testable import shengci

struct StrokeOrderDataTests {
    @Test func decodesKnownCharacterAndPreservesStrokeOrder() throws {
        let store = try StrokeOrderDataStore(data: Data("""
        {
          "好": {
            "character": "好",
            "strokes": [
              {
                "path": [["M", 100, 200], ["L", 300, 400], ["Z"]],
                "median": [[100, 200], [300, 400]]
              },
              {
                "path": [["M", 500, 600], ["Q", 550, 650, 700, 800]],
                "median": [[500, 600], [700, 800]]
              }
            ]
          }
        }
        """.utf8))

        let character = try #require(store.character(for: "好"))

        #expect(character.character == "好")
        #expect(character.strokes.count == 2)
        #expect(character.strokes[0].median.first == StrokeOrderPoint(x: 100, y: 200))
        #expect(character.strokes[1].commands.first == .move(StrokeOrderPoint(x: 500, y: 600)))
    }

    @Test func missingCharacterReturnsNil() throws {
        let store = try StrokeOrderDataStore(data: Data("{}".utf8))

        #expect(store.character(for: "未") == nil)
    }

    @Test func normalizedCoordinatesMapToTheDrawingRectangle() {
        let point = StrokeOrderPoint(x: 256, y: 768)

        #expect(point.cgPoint(in: CGRect(x: 10, y: 20, width: 200, height: 100)) == CGPoint(x: 85, y: 95))
    }

    @Test func malformedStrokeDataIsRejected() {
        #expect(throws: Error.self) {
            try StrokeOrderDataStore(data: Data("{\"好\":{}}".utf8))
        }
    }
}
