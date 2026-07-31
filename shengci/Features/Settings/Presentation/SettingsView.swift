//
//  SettingsView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import StoreKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var isPaywallPresented = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamBackground
                    .ignoresSafeArea()

                List {
                    Section {
                        if subscriptions.isPremium {
                            Button(action: manageSubscription) {
                                Label(
                                    "Premium Active",
                                    systemImage: "checkmark.seal.fill"
                                )
                            }
                        } else {
                            Button {
                                isPaywallPresented = true
                            } label: {
                                Label(
                                    "Upgrade to Shengci Premium",
                                    systemImage: "crown.fill"
                                )
                            }

                            Button(action: restorePurchases) {
                                if isRestoring {
                                    ProgressView()
                                } else {
                                    Label(
                                        "Restore Purchases",
                                        systemImage: "arrow.clockwise"
                                    )
                                }
                            }
                            .disabled(isRestoring)
                        }
                    } header: {
                        Text("Premium")
                    } footer: {
                        Text(
                            subscriptions.isPremium
                                ? "Manage your subscription with Apple."
                                : "Unlock unlimited Scan and HSK 3–9."
                        )
                    }
                    .listRowBackground(Color.warmIvoryCard)

                    // MARK: - Saved Characters Navigation Section
                    Section {
                        NavigationLink {
                            SavedWordsView()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.roseAccent.opacity(0.15))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.roseAccent)
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text("Saved Characters")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(
                                            Color.darkForeground
                                        )

                                    Text(
                                        "View and listen to your saved words"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        Color.darkForeground
                                            .opacity(0.65)
                                    )
                                }
                            }
                        }
                        .listRowBackground(Color.warmIvoryCard)
                    } header: {
                        Text("Saved")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }

                    // MARK: - Progress Navigation Section
                    Section {
                        NavigationLink {
                            PracticeProgressView()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.tealAccent.opacity(0.15))
                                        .frame(width: 38, height: 38)

                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.tealAccent)
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {
                                    Text("Practice Progress")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(
                                            Color.darkForeground
                                        )

                                    Text(
                                        "View completed words grouped by HSK level"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        Color.darkForeground
                                            .opacity(0.65)
                                    )
                                }
                            }
                        }
                        .listRowBackground(Color.warmIvoryCard)
                    } header: {
                        Text("Progress")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.darkForeground.opacity(0.6))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color.creamBackground,
                for: .navigationBar
            )
        }
        .sheet(isPresented: $isPaywallPresented) {
            PremiumPaywall()
        }
        .alert(
            "Premium",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await subscriptions.restore()
                if !subscriptions.isPremium {
                    errorMessage = "No active premium purchase was found."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func manageSubscription() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            errorMessage = "Subscription management is unavailable right now."
            return
        }

        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SubscriptionManager())
}
