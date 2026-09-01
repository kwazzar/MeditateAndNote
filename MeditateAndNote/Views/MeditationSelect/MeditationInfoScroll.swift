//
//  MeditationInfoScroll.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.11.2025.
//

import SwiftUI

// MARK: - Meditation Info Sheet
struct MeditationInfoSheet: View {
    let meditation: Meditation
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    init(_ meditation: Meditation) {
        self.meditation = meditation
    }

    var body: some View {
        Group {
            VStack(spacing: 0) {
                HStack {
                    Text("Meditation Info")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.current.textPrimary)

                    Spacer()

                    Button("Close") {
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.textSecondary)
                }
                .padding()
                .background(themeManager.current.toolbarBackground)

                MeditationInfoScroll(meditation: meditation)
                    .padding()
            }
        }
        .background(themeManager.current.mainBackground.ignoresSafeArea())
    }

    private func meditationIcon(for title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("breath") {
            return "wind"
        } else if lowercased.contains("sleep") {
            return "moon"
        } else if lowercased.contains("focus") {
            return "target"
        } else if lowercased.contains("calm") || lowercased.contains("relax") {
            return "leaf"
        } else if lowercased.contains("mindful") {
            return "brain.head.profile"
        } else {
            return "circle.dotted"
        }
    }
}

// MARK: - Meditation Info Scroll
struct MeditationInfoScroll: View {
    let meditation: Meditation
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerScroll

                Divider()
                    .foregroundStyle(themeManager.current.dividerColor)

                categoryBadge
                breathPattern
                detailScroll
                cycleDuration
                styleOfBreating

                if let description = meditation.description, !description.isEmpty {
                    descriptionView(description)
                }

                Spacer(minLength: 20)
            }
        }
        .padding(.horizontal)
    }
}

private extension MeditationInfoScroll {
    func phaseDuration(for type: BreathingPhaseType) -> TimeInterval? {
        meditation.breathingStyle.pattern.phases.first { $0.type == type }?.duration
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds) s"
    }

    @ViewBuilder
    var headerScroll: some View {
        HStack(spacing: 16) {
            Image(systemName: meditationIcon(for: meditation.title.rawValue))
                .font(.system(size: 40))
                .foregroundColor(themeManager.current.streakActiveNote)
                .frame(width: 60, height: 60)
                .background(themeManager.current.streakActiveNote.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(meditation.title.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.current.textPrimary)

                Text(meditation.breathingStyle.pattern.name)
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.textSecondary)
            }

            Spacer()
        }
    }

    var categoryBadge: some View {
        HStack {
            Image(systemName: "tag.fill")
                .foregroundColor(themeManager.current.streakActiveMeditation)
            Text(meditation.category.rawValue.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.current.streakActiveMeditation.opacity(0.1))
        .cornerRadius(8)
    }

    var breathPattern: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wind")
                    .foregroundColor(themeManager.current.streakActiveNote)
                Text("Breathing Pattern")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            Text(meditation.breathingStyle.pattern.name)
                .font(.body)
                .foregroundColor(themeManager.current.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.current.dividerColor)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    var styleOfBreating: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.circle")
                    .foregroundColor(themeManager.current.streakActiveMeditation)
                Text("Breathing Style")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            Text(meditation.breathingStyle.rawValue)
                .font(.body)
                .foregroundColor(themeManager.current.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeManager.current.streakActiveMeditation.opacity(0.1))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    func descriptionView(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(themeManager.current.streakActiveNote)
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            Text(description)
                .font(.body)
                .foregroundColor(themeManager.current.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var detailScroll: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(themeManager.current.streakActiveNote)
                Text("Pattern Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let inhale = phaseDuration(for: .inhale) {
                    PatternDetailRow(
                        title: "Inhale",
                        value: formatDuration(inhale),
                        icon: "arrow.down.circle"
                    )
                }

                if let holdIn = phaseDuration(for: .holdAfterInhale) {
                    PatternDetailRow(
                        title: "Hold In",
                        value: formatDuration(holdIn),
                        icon: "pause.circle"
                    )
                }

                if let exhale = phaseDuration(for: .exhale) {
                    PatternDetailRow(
                        title: "Exhale",
                        value: formatDuration(exhale),
                        icon: "arrow.up.circle"
                    )
                }

                if let holdOut = phaseDuration(for: .holdAfterExhale) {
                    PatternDetailRow(
                        title: "Hold Out",
                        value: formatDuration(holdOut),
                        icon: "pause.circle"
                    )
                }
            }
            .padding(.leading, 16)
        }
    }

    var cycleDuration: some View {
        let total = meditation.breathingStyle.pattern.phases.reduce(0) { $0 + $1.duration }
        return HStack {
            Image(systemName: "clock.badge.checkmark")
                .foregroundColor(themeManager.current.streakSuccess)
            Text("Full Cycle")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.current.textPrimary)
            Spacer()
            Text(formatDuration(total))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.streakSuccess)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.current.streakSuccess.opacity(0.1))
        .cornerRadius(8)
    }

    func meditationIcon(for title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("breath") {
            return "wind"
        } else if lowercased.contains("sleep") {
            return "moon"
        } else if lowercased.contains("focus") {
            return "target"
        } else if lowercased.contains("calm") || lowercased.contains("relax") {
            return "leaf"
        } else if lowercased.contains("mindful") {
            return "brain.head.profile"
        } else {
            return "circle.dotted"
        }
    }
}

// MARK: - Pattern Detail Row
struct PatternDetailRow: View {
    let title: String
    let value: String
    let icon: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.current.textSecondary)
                .frame(width: 20)

            Text(title)
                .font(.body)
                .foregroundColor(themeManager.current.textPrimary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.streakActiveNote)
        }
        .padding(.vertical, 4)
    }
}


struct MeditationInfoScroll_Previews: PreviewProvider {
    static var previews: some View {
        MeditationInfoScroll(meditation: Meditation(id: "1", title: MeditationTitle("Morning Mindfulness"), breathingStyle: .fourEight, description: "Start your day with awareness", category: .mindfulness))
    }
}
