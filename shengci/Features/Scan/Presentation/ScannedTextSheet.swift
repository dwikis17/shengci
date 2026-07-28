import SwiftUI

struct ScannedTextSheet: View {
  let selection: ScannedTextSelection

  @Environment(\.dismiss) private var dismiss
  @State private var mode = ChineseTextSegmentationMode.words
  @State private var tokens: [ScannedToken] = []
  @State private var isLoading = true

  private let segmenter: ChineseTextSegmenter

  init(
    selection: ScannedTextSelection,
    segmenter: ChineseTextSegmenter = ChineseTextSegmenter()
  ) {
    self.selection = selection
    self.segmenter = segmenter
  }

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView("Finding dictionary words…")
        } else if tokens.isEmpty {
          ContentUnavailableView(
            "No Chinese Text",
            systemImage: "text.magnifyingglass",
            description: Text("Try selecting another highlighted region.")
          )
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              Text(selection.transcript)
                .font(.title2.bold())
                .foregroundStyle(Color.darkForeground)
                .textSelection(.enabled)

              Picker("Segmentation", selection: $mode) {
                ForEach(ChineseTextSegmentationMode.allCases) { option in
                  Text(option.rawValue).tag(option)
                }
              }
              .pickerStyle(.segmented)

              LazyVGrid(
                columns: [
                  GridItem(.adaptive(minimum: 72), spacing: 10),
                ],
                alignment: .leading,
                spacing: 10
              ) {
                ForEach(tokens) { token in
                  NavigationLink(value: token) {
                    Text(token.text)
                      .font(.title3.bold())
                      .frame(minWidth: 44, minHeight: 44)
                      .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(.bordered)
                  .tint(Color.royalBlueAccent)
                  .accessibilityHint("Shows pronunciation and definitions")
                }
              }
            }
            .padding()
          }
        }
      }
      .background(Color.creamBackground)
      .navigationTitle("Choose a Word")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: ScannedToken.self) { token in
        ScannedWordDetailView(token: token)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done", action: dismiss.callAsFunction)
        }
      }
      .task(id: mode) {
        await loadTokens()
      }
    }
  }

  private func loadTokens() async {
    isLoading = true
    let segmentedTokens = await segmenter.segment(
      selection.transcript,
      mode: mode
    )
    guard !Task.isCancelled else { return }
    tokens = segmentedTokens
    isLoading = false
  }
}
