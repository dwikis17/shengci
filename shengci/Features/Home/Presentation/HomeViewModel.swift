//
//  HomeViewModel.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var wordList: [WordModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    init() {
        loadWords()
    }
    
    func loadWords(from fileName: String = "hsk1") {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let url = findJSONURL(fileName: fileName) else {
                    throw NSError(
                        domain: "HomeViewModel",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "JSON file '\(fileName).json' not found in bundle."]
                    )
                }
                
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let words = try decoder.decode([WordModel].self, from: data)
                
                self.wordList = words.shuffled()
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load vocabulary: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private nonisolated func findJSONURL(fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            return url
        }
        
        // Fallback for previews/tests: look for matching file in bundle or file system
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            if let target = urls.first(where: { $0.lastPathComponent == "\(fileName).json" }) {
                return target
            }
        }
        
        return nil
    }
}
