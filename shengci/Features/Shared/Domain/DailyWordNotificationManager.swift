import Foundation
import UserNotifications

actor DailyWordNotificationManager {
    static let shared = DailyWordNotificationManager()
    static let enabledKey = "dailyWordNotificationsEnabled"

    private static let identifierPrefix = "daily-word-"
    private let center = UNUserNotificationCenter.current()

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            await removeScheduledNotifications()
            return false
        }

        let settings = await center.notificationSettings()
        let authorized: Bool

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorized = true
        case .notDetermined:
            authorized =
                (try? await center.requestAuthorization(options: [.alert, .sound]))
                ?? false
        case .denied:
            authorized = false
        @unknown default:
            authorized = false
        }

        guard authorized else { return false }

        do {
            try await replaceScheduledNotifications()
            return true
        } catch {
            await removeScheduledNotifications()
            return false
        }
    }

    func refreshIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }

        guard await setEnabled(true) else {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return
        }
    }

    static func makeRequests(
        from now: Date,
        calendar inputCalendar: Calendar = .autoupdatingCurrent,
        count: Int = 60
    ) -> [UNNotificationRequest] {
        let calendar = inputCalendar

        let today = calendar.startOfDay(for: now)
        guard
            let todayAtNine = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: today
            ),
            let firstDelivery =
                todayAtNine > now
                ? todayAtNine
                : calendar.date(byAdding: .day, value: 1, to: todayAtNine)
        else {
            return []
        }

        return (0..<count).compactMap { offset in
            guard
                let delivery = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: firstDelivery
                )
            else {
                return nil
            }

            let word = WordOfTheDayManager.shared.getWord(for: delivery)
            let content = UNMutableNotificationContent()
            content.title = word.simplified
            content.body = [word.formattedPinyin, word.meanings.first]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: delivery
            )
            let identifier =
                "\(Self.identifierPrefix)\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"

            return UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )
            )
        }
    }

    private func replaceScheduledNotifications() async throws {
        await removeScheduledNotifications()
        for request in Self.makeRequests(from: Date()) {
            try await center.add(request)
        }
    }

    private func removeScheduledNotifications() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
