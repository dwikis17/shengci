struct PremiumAccess {
    let isPremium: Bool

    func allowsHSKLevel(_ level: Int) -> Bool {
        isPremium || level <= 2
    }

    func allowsScanResult(hasUsedFreeResult: Bool) -> Bool {
        isPremium || !hasUsedFreeResult
    }
}
