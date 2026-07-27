//
//  HomeViewModel.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var wordList: [WordModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentLevel: Int = 1

    init(level: Int = 1) {
        self.currentLevel = level
        loadWords(level: level)
    }

    func loadWords(level: Int) {
        self.currentLevel = level
        isLoading = true
        errorMessage = nil

        let fileName = "hsk\(level)"

        Task {
            do {
                guard let url = findJSONURL(fileName: fileName) else {
                    throw NSError(
                        domain: "HomeViewModel",
                        code: 404,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "JSON file '\(fileName).json' not found in bundle."
                        ]
                    )
                }

                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let words = try decoder.decode([WordModel].self, from: data)

                self.wordList = words
                self.isLoading = false
            } catch {
                self.errorMessage =
                    "Failed to load HSK \(level) vocabulary: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private nonisolated func findJSONURL(fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json")
        {
            return url
        }

        if let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: nil
        ) {
            if let target = urls.first(where: {
                $0.lastPathComponent == "\(fileName).json"
            }) {
                return target
            }
        }

        return nil
    }
}
