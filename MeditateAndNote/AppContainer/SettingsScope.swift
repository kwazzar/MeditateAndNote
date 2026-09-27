//
//  SettingsScope.swift
//  MeditateAndNote
//

import Foundation

struct SettingsScope {
    let soundSettings: SoundSettings
    let animationSettings: AnimationSettings
    let onboardingStore: any OnboardingStore
    let reminderManager: ReminderManager

    init() {
        soundSettings = SoundSettings.shared
        animationSettings = AnimationSettings.shared
        onboardingStore = UserDefaultsOnboardingStore()
        reminderManager = ReminderManager(
            store: UserDefaultsReminderSettingsStore(),
            scheduler: SystemNotificationScheduler()
        )
    }
}
