//
//  SettingsScope.swift
//  MeditateAndNote
//

import Foundation

struct SettingsScope {
    let onboardingStore: any OnboardingStore
    let reminderManager: ReminderManager

    init() {
        onboardingStore = UserDefaultsOnboardingStore()
        reminderManager = ReminderManager(
            store: UserDefaultsReminderSettingsStore(),
            scheduler: SystemNotificationScheduler()
        )
    }

    // ponytail: UI-настройки живуть на MainActor, тож scope не створює їх у
    // власному init — він віддає `@MainActor`-computed, який читає singleton
    // у момент звернення. Інакше DI-контейнер змушений бути MainActor, а
    // `EnvironmentKey.defaultValue` вимагає nonisolated.
    @MainActor var soundSettings: SoundSettings { .shared }
    @MainActor var animationSettings: AnimationSettings { .shared }
}
