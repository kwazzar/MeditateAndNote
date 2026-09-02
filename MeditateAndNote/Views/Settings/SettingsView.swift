//
//  SettingsView.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import SwiftUI

//MARK: - SettingsView

struct SettingsView: View {
    @Bindable var animationSettings: AnimationSettings
    @Bindable var soundSettings: SoundSettings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    animationSection
                    themeSection
                    volumeSection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .top) {
            navigationBar
        }
    }
}

//MARK: - Extension
private extension SettingsView {
    var navigationBar: some View {
        ZStack {
            Text("Settings")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.textPrimary)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.current.iconPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
        }
        .padding(.horizontal)
        .frame(height: 44)
    }

    var animationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Meditation Animation", icon: "waveform.path.ecg")

            Picker("Animation", selection: $animationSettings.style) {
                ForEach(BreathingAnimationStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .tint(themeManager.current.streakActiveMeditation)
        }
        .padding(20)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
    }

    var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("App Theme", icon: "paintpalette.fill")

            ForEach(MainTheme.allCases, id: \.self) { theme in
                Button {
                    themeManager.current = theme
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: theme.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme == themeManager.current
                                            ? themeManager.current.streakActiveMeditation
                                            : themeManager.current.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(theme.swatch)
                            )

                        Text(theme.displayName)
                            .font(.body)
                            .foregroundColor(themeManager.current.textPrimary)

                        Spacer()

                        if theme == themeManager.current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.current.streakActiveMeditation)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
    }

    var volumeSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Meditation Sound Volume", icon: "speaker.wave.2.fill")

            HStack {
                Text("\(Int(soundSettings.volume * 100))%")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(themeManager.current.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Slider(value: $soundSettings.volume, in: 0...1)
                .tint(themeManager.current.streakActiveMeditation)

            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(themeManager.current.textSecondary)
                Spacer()
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(themeManager.current.textSecondary)
            }
        }
        .padding(20)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
    }

    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.current.streakActiveMeditation)
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.current.textPrimary)
        }
    }
}

//MARK: - Display names (presentation layer)

extension BreathingAnimationStyle {
    var displayName: String {
        switch self {
        case .rings: "Rings"
        case .path: "Path"
        }
    }
}

extension MainTheme {
    var swatch: Color {
        switch self {
        case .liquidGlass: .blue
        case .breathing: .mint
        case .softDawn: .orange
        case .darkZen: .indigo
        case .obsidian: .gray
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            animationSettings: AnimationSettings(),
            soundSettings: SoundSettings()
        )
        .environment(ThemeManager())
    }
}
