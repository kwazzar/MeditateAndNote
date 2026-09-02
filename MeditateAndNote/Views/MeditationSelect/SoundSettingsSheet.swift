//
//  SoundSettingsSheet.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import SwiftUI

//MARK: - SoundSettingsSheet

struct SoundSettingsSheet: View {
    @Bindable var soundSettings: SoundSettings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    private let soundPlayer: SoundPlaying = SoundPlayer.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(themeManager.current.streakActiveMeditation)

                volumeSection

                previewButton

                Spacer()
            }
            .padding(24)
            .background(themeManager.current.mainBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.current.iconPrimary)
                            .frame(width: 32, height: 32)
                            .background(themeManager.current.toolbarBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }
}

//MARK: - Extension
private extension SoundSettingsSheet {
    var volumeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Sound Volume")
                    .font(.headline)
                    .foregroundColor(themeManager.current.textPrimary)

                Spacer()

                Text("\(Int(soundSettings.volume * 100))%")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(themeManager.current.textSecondary)
            }

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

    var previewButton: some View {
        Button {
            soundPlayer.play(.phase(.inhale))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                Text("Play sample")
            }
            .font(.headline)
            .foregroundColor(themeManager.current.buttonText)
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.current.accentButton)
            .cornerRadius(12)
        }
    }
}

struct SoundSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        SoundSettingsSheet(soundSettings: SoundSettings())
            .environment(ThemeManager())
    }
}