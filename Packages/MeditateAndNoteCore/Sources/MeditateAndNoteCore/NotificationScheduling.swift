//
//  NotificationScheduling.swift
//  MeditateAndNoteCore
//

import Foundation

/// Thin abstraction over a platform notification centre so `ReminderManager`
/// stays testable without any system framework. Deliberately keeps the domain
/// free of `UserNotifications` types — only `Bool`/`Date` cross the boundary.
public protocol NotificationScheduling: Sendable {
    func isAuthorized() async -> Bool
    func requestAuthorization() async -> Bool
    /// Removes this app's reminder notifications (scoped to their identifier
    /// prefix), never every pending request on the system.
    func removeAllPendingNotifications()
    func scheduleNotification(id: String, title: String, body: String, at date: Date)
}
