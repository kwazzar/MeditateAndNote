//
//  NotificationScheduling.swift
//  MeditateAndNote
//

import Foundation
import UserNotifications

/// Thin abstraction over `UNUserNotificationCenter` so `ReminderManager` stays
/// testable without the system framework. Deliberately keeps the domain free of
/// `UserNotifications` types — only `Bool`/`Date` flow across the boundary.
protocol NotificationScheduling {
    func isAuthorized() async -> Bool
    func requestAuthorization() async -> Bool
    func removeAllPendingNotifications()
    func scheduleNotification(id: String, title: String, body: String, at date: Date)
}

/// Adapter over `UNUserNotificationCenter`. Also acts as its delegate so
/// banners still appear while the app is in the foreground.
final class SystemNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func scheduleNotification(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}