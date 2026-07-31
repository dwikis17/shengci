import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    static let entitlementIdentifier = "premium"

    private(set) var isPremium = false
    private(set) var hasLoaded = false

    var access: PremiumAccess {
        PremiumAccess(isPremium: isPremium)
    }

    func refresh() async {
        if !hasLoaded, let cached = Purchases.shared.cachedCustomerInfo {
            apply(cached)
        }

        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            hasLoaded = true
        }
    }

    func restore() async throws {
        apply(try await Purchases.shared.restorePurchases())
    }

    func apply(_ customerInfo: CustomerInfo) {
        isPremium =
            customerInfo.entitlements[Self.entitlementIdentifier]?.isActive
            == true
        hasLoaded = true
    }
}
