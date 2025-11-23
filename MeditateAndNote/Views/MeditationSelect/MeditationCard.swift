//
//  MeditationCard.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.08.2025.
//

import SwiftUI

struct MeditationCard: View {
    let meditation: Meditation
    let isSelected: Bool
    let onSelect: () -> Void
    let onLongPress: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: meditationIcon(for: meditation.title))
                    .font(.title2)
                    .foregroundColor(.blue)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Text(meditation.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(meditation.breathingStyle.pattern.name) pattern")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            onLongPress?()
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
