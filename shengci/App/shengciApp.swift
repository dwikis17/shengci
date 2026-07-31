//
//  shengciApp.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import CoreData
import RevenueCat
import SwiftData
import SwiftUI

@main
struct shengciApp: App {
    private static let cloudContainerIdentifier = "iCloud.com.dwiki.shengci"

    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionManager()
    private let modelContainer: ModelContainer

    init() {
        // Replace this Test Store key with the Apple public SDK key before
        // testing App Store products or shipping.
        Purchases.configure(withAPIKey: "appl_sMPBEpmVOeSneZPoqdRPtKrpbEx")

        let schema = Schema([
            SavedWord.self,
            PracticeSessionRecord.self,
            LearningSyncState.self,
        ])
        let cloudDatabase: ModelConfiguration.CloudKitDatabase =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]
                == nil
                ? .private(Self.cloudContainerIdentifier)
                : .none
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: cloudDatabase
        )

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-InitializeCloudKitSchema") {
            do {
                try CloudKitSchemaInitializer.initialize(
                    configuration: configuration,
                    containerIdentifier: Self.cloudContainerIdentifier,
                    modelTypes: [
                        SavedWord.self,
                        PracticeSessionRecord.self,
                        LearningSyncState.self,
                    ]
                )
            } catch {
                fatalError("CloudKit schema initialization failed: \(error)")
            }
        }
        #endif

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to open the learning data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptions)
                .preferredColorScheme(.light)
                .task {
                    try? LearningDataSync.reconcile(
                        in: modelContainer.mainContext
                    )
                    await subscriptions.refresh()
                    await DailyWordNotificationManager.shared.refreshIfEnabled()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        try? LearningDataSync.reconcile(
                            in: modelContainer.mainContext
                        )
                        await subscriptions.refresh()
                        await DailyWordNotificationManager.shared.refreshIfEnabled()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .NSPersistentStoreRemoteChange
                    )
                ) { _ in
                    try? LearningDataSync.reconcile(
                        in: modelContainer.mainContext
                    )
                }
        }
        .modelContainer(modelContainer)
    }
}
