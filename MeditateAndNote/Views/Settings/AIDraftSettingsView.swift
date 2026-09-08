//
//  AIDraftSettingsView.swift
//  MeditateAndNote
//
//  Settings UI for AI draft generation preferences.
//

import SwiftUI

struct AIDraftSettingsView: View {
    @Bindable var settingsStore: AIDraftSettingsStoreObservable
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("AI Settings", icon: "sparkles")

            Toggle("Use remote AI when on-device unavailable", isOn: $settingsStore.settings.useRemoteFallback)
                .tint(themeManager.current.streakActiveMeditation)

            if settingsStore.settings.useRemoteFallback {
                remoteEndpointSection
                modelSelectionSection
                dailyLimitSection
            }

            privacyNotice
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
    }

    private var remoteEndpointSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remote Endpoint")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            TextField("https://api.openai.com/v1/chat/completions", text: $settingsStore.settings.remoteEndpointURL)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            Picker("Model", selection: $settingsStore.settings.selectedModel) {
                Text("gpt-4o-mini").tag("gpt-4o-mini")
                Text("gpt-4o").tag("gpt-4o")
                Text("claude-3-5-sonnet-20241022").tag("claude-3-5-sonnet-20241022")
            }
            .pickerStyle(.menu)
        }
    }

    private var dailyLimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Generation Limit: \(settingsStore.settings.dailyGenerationLimit)")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            Slider(value: Binding(
                get: { Double(settingsStore.settings.dailyGenerationLimit) },
                set: { newValue in
                    settingsStore.settings.dailyGenerationLimit = Int(newValue.rounded())
                }
            ), in: 1...50, step: 1)
        }
    }

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy Notice")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            Text("AI generations are processed remotely. Your note content is sent to the provider.")
                .font(.caption2)
                .foregroundColor(themeManager.current.textSecondary)

            Button("Save API Key") {
                Task {
                    try? await settingsStore.saveAPIKey("...")
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.current.streakActiveMeditation)
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.current.textPrimary)
        }
    }
}

struct AIDraftSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AIDraftSettingsView(
            settingsStore: AIDraftSettingsStoreObservable()
        )
        .environment(ThemeManager())
    }
}