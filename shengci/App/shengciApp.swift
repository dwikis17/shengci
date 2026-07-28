//
//  shengciApp.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftUI
import SwiftData

@main
struct shengciApp: App {
    init() {
        CEDICTStore.shared.preload()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedWord.self)
    }
}
