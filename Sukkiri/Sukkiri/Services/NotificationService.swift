import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let accumulationID = "sukkiri.screenshots.accumulated"
    static let threshold = 10

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // isPastPhotosDigested == true のときにのみ呼ぶこと
    func scheduleIfNeeded(unreviewedCount: Int) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [accumulationID])

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        guard unreviewedCount >= Self.threshold else { return }

        let content = UNMutableNotificationContent()
        content.title = "スクショが溜まっています"
        content.body = "スクショが\(unreviewedCount)枚溜まっています。サクッとスッキリしませんか？"
        content.sound = .default

        // 翌朝9時に通知
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: accumulationID, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
