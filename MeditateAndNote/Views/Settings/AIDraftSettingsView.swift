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
    @State private var hasStoredKey = false
    @State private var keyMessage: String?
    @State private var keyMessageIsError = false

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
        // The controls above mutate the in-memory copy; persist every change
        // or the service (which reads its own store instance) keeps seeing
        // stale defaults — e.g. the toggle silently does nothing.
        .onChange(of: settingsStore.settings) { _, newValue in
            settingsStore.saveSettings(newValue)
        }
        .task {
            hasStoredKey = settingsStore.getAPIKey() != nil
        }
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

            // Free-text (not a Picker): providers come and go (OpenAI,
            // Gemini via its OpenAI-compat endpoint, OpenRouter…), hardcoding
            // three names would block all of them. Persists via the view's
            // onChange → saveSettings like the other fields.
            TextField("gpt-4o-mini", text: $settingsStore.settings.selectedModel)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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

            apiKeySection
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hasStoredKey ? "API key saved ✓" : "No API key saved")
                .font(.caption)
                .foregroundColor(themeManager.current.textSecondary)

            SecureField("sk-...", text: $settingsStore.draftAPIKey)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let keyMessage {
                Text(keyMessage)
                    .font(.caption2)
                    .foregroundColor(keyMessageIsError ? themeManager.current.danger : themeManager.current.textSecondary)
            }

            HStack(spacing: 16) {
                Button("Save API Key") {
                    Task {
                        do {
                            try await settingsStore.saveAPIKey(settingsStore.draftAPIKey)
                            settingsStore.draftAPIKey = ""
                            hasStoredKey = true
                            keyMessage = nil
                        } catch {
                            keyMessage = "Couldn't save the key. Try again."
                            keyMessageIsError = true
                        }
                    }
                }
                .disabled(settingsStore.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if hasStoredKey {
                    Button("Delete", role: .destructive) {
                        do {
                            try settingsStore.deleteAPIKey()
                            hasStoredKey = false
                            keyMessage = nil
                        } catch {
                            keyMessage = "Couldn't delete the key."
                            keyMessageIsError = true
                        }
                    }
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