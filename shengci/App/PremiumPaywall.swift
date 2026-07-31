import RevenueCat
import RevenueCatUI
import SwiftUI

struct PremiumPaywall: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted(handle)
            .onRestoreCompleted(handle)
            .onRequestedDismissal {
                dismiss()
            }
    }

    private func handle(_ customerInfo: CustomerInfo) {
        subscriptions.apply(customerInfo)
        guard subscriptions.isPremium else { return }
        dismiss()
    }
}
