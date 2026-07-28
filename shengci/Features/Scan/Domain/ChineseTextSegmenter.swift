nonisolated struct ChineseTextSegmenter: Sendable {
  private static let maximumWordLength = 8

  private let lexicon: any ChineseLexicon

  init(lexicon: any ChineseLexicon = CEDICTStore.shared) {
    self.lexicon = lexicon
  }

  func segment(
    _ text: String,
    mode: ChineseTextSegmentationMode
  ) async -> [ScannedToken] {
    let runs = ChineseText.runs(in: text)
    guard !runs.isEmpty else { return [] }

    let candidates = candidateTerms(in: runs, mode: mode)
    let exactEntries = await lexicon.exactEntries(for: candidates)

    return runs.enumerated().flatMap { runIndex, run in
      switch mode {
      case .words:
        wordTokens(
          in: run,
          runIndex: runIndex,
          exactEntries: exactEntries
        )
      case .characters:
        characterTokens(
          in: run,
          runIndex: runIndex,
          exactEntries: exactEntries
        )
      }
    }
  }

  private func candidateTerms(
    in runs: [String],
    mode: ChineseTextSegmentationMode
  ) -> Set<String> {
    switch mode {
    case .words:
      Set(runs.flatMap(allCandidateTerms))
    case .characters:
      Set(runs.flatMap(ChineseText.characters))
    }
  }

  private func allCandidateTerms(in run: String) -> [String] {
    let characters = Array(run)

    return characters.indices.flatMap { startIndex in
      let remainingCount = characters.count - startIndex
      let maximumLength = min(Self.maximumWordLength, remainingCount)

      return (1...maximumLength).map { length in
        String(characters[startIndex..<(startIndex + length)])
      }
    }
  }

  private func wordTokens(
    in run: String,
    runIndex: Int,
    exactEntries: [String: [CEDICTEntry]]
  ) -> [ScannedToken] {
    let characters = Array(run)
    var tokens: [ScannedToken] = []
    var offset = 0

    while offset < characters.count {
      let remainingCount = characters.count - offset
      let maximumLength = min(Self.maximumWordLength, remainingCount)
      var selectedLength = 1
      var selectedText = String(characters[offset])

      for length in stride(from: maximumLength, through: 1, by: -1) {
        let candidate = String(characters[offset..<(offset + length)])
        if exactEntries[candidate]?.isEmpty == false {
          selectedLength = length
          selectedText = candidate
          break
        }
      }

      tokens.append(
        ScannedToken(
          id: "\(runIndex)-\(offset)-\(selectedText)",
          text: selectedText,
          entries: exactEntries[selectedText] ?? [],
        )
      )
      offset += selectedLength
    }

    return tokens
  }

  private func characterTokens(
    in run: String,
    runIndex: Int,
    exactEntries: [String: [CEDICTEntry]]
  ) -> [ScannedToken] {
    ChineseText.characters(in: run).enumerated().map { offset, character in
      ScannedToken(
        id: "\(runIndex)-\(offset)-\(character)",
        text: character,
        entries: exactEntries[character] ?? [],
      )
    }
  }
}
