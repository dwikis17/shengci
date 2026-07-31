//
//  shengciApp.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import RevenueCat
import SwiftData
import SwiftUI

@main
struct shengciApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionManager()

    init() {
        // Replace this Test Store key with the Apple public SDK key before
        // testing App Store products or shipping.
        Purchases.configure(withAPIKey: "test_RfQzXDCWWIqIXxiUfsNOEKmdmBR")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptions)
                .preferredColorScheme(.light)
                .task {
                    await subscriptions.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await subscriptions.refresh()
                    }
                }
        }
        .modelContainer(for: [SavedWord.self, PracticeSessionRecord.self])
    }
}
