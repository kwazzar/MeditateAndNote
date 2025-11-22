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
    @Binding var isPresented: Bool

    var body: some View {
        Group {
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Text("Meditation Info")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Done") {
                        isPresented = false
                    }
                    .font(.body)
                    .fontWeight(.medium)
                }
                .padding()
                .background(Color(UIColor.systemGray6))

                #warning("ScrollView content")
                // ScrollView content
                MeditationInfoScroll(meditation: meditation)
                .padding()
            }
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header з іконкою та заголовком
                headerScroll

                Divider()

                // Дихальний патерн
                breathPattern

                // Детальна інформація про дихальний патерн
                detailScroll

                // Стиль дихання
                styleOfBreating

                //                     Опис (якщо є)
                if let description = meditation.breathingStyle.rawValue {
                    descriptionView(description)
                }

                Spacer(minLength: 20)
            }
        }
                    .padding(.horizontal)
        // Optional: add horizontal padding to the entire content
    }
}

private extension MeditationInfoScroll {
    @ViewBuilder
    var headerScroll: some View {
        HStack(spacing: 16) {
            Image(systemName: meditationIcon(for: meditation.title))
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(meditation.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Meditation Session")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    var breathPattern: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wind")
                    .foregroundColor(.blue)
                Text("Breathing Pattern")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(meditation.breathingStyle.pattern.name)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    var styleOfBreating: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.circle")
                    .foregroundColor(.blue)
                Text("Breathing Style")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(meditation.breathingStyle.rawValue)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    func descriptionView(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
                Text("Description")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var detailScroll: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Pattern Details")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                PatternDetailRow(
                    title: "Inhale",
                    value: "s",
                    icon: "arrow.down.circle"
                )

                PatternDetailRow(
                    title: "Hold In",
                    value: "s",
                    icon: "pause.circle"
                )

                PatternDetailRow(
                    title: "Exhale",
                    value: "s",
                    icon: "arrow.up.circle"
                )

                PatternDetailRow(
                    title: "Hold Out",
                    value: "s",
                    icon: "pause.circle"
                )
            }
            .padding(.leading, 16)
        }
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

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}


struct MeditationInfoScroll_Previews: PreviewProvider {
    static var previews: some View {
        MeditationInfoScroll(meditation: Meditation(id: "1", title: "Morning Mindfulness", breathingStyle: .fourEight, description: "Start your day with awareness", category: .mindfulness))
    }
}
