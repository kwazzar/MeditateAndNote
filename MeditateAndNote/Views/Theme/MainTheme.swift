//
//  MainTheme.swift
//  MeditateAndNote
//
//  Created by kwazzar on 22.07.2026.
//

import SwiftUI

enum MainTheme: String, CaseIterable {
    case liquidGlass, breathing, softDawn, darkZen, obsidian
}

extension MainTheme {
    var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .breathing: "Breathing"
        case .softDawn: "Soft Dawn"
        case .darkZen: "Dark Zen"
        case .obsidian: "Obsidian"
        }
    }

    var iconName: String {
        switch self {
        case .liquidGlass: "drop.fill"
        case .breathing: "wind"
        case .softDawn: "sunrise.fill"
        case .darkZen: "moon.stars.fill"
        case .obsidian: "flame.fill"
        }
    }
}

extension MainTheme {
    @ViewBuilder
    var mainBackground: some View {
        switch self {
        case .liquidGlass:
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        case .breathing:
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        case .darkZen:
            Color(red: 0.06, green: 0.08, blue: 0.14)
                .ignoresSafeArea()
                .overlay(
                    Canvas { context, size in
                        for _ in 0..<40 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                with: .color(.white.opacity(0.08))
                            )
                        }
                    }
                )
        case .softDawn:
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.94, blue: 0.88),
                    Color(red: 0.95, green: 0.90, blue: 0.98),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        case .obsidian:
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.07),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    var textPrimary: Color {
        switch self {
        case .liquidGlass: .primary
        case .breathing: .primary
        case .darkZen: .white
        case .softDawn: .primary
        case .obsidian: .white
        }
    }
    
    var textSecondary: Color {
        switch self {
        case .liquidGlass: .secondary
        case .breathing: .secondary
        case .darkZen: .white.opacity(0.6)
        case .softDawn: .secondary
        case .obsidian: .white.opacity(0.6)
        }
    }
    
    var iconPrimary: Color {
        switch self {
        case .liquidGlass: .primary
        case .breathing: .primary
        case .darkZen: .white
        case .softDawn: .primary
        case .obsidian: .white
        }
    }
    
    var toolbarBackground: Color {
        switch self {
        case .liquidGlass: Color.white.opacity(0.1)
        case .breathing: Color.white.opacity(0.1)
        case .darkZen: Color.white.opacity(0.1)
        case .softDawn: Color.black.opacity(0.1)
        case .obsidian: Color.white.opacity(0.1)
        }
    }
    
    var dividerColor: Color {
        switch self {
        case .liquidGlass: Color.black.opacity(0.1)
        case .breathing: Color.black.opacity(0.1)
        case .darkZen: Color.white.opacity(0.1)
        case .softDawn: Color.black.opacity(0.1)
        case .obsidian: Color.white.opacity(0.1)
        }
    }
    
    var editorBackground: Color {
        switch self {
        case .liquidGlass: Color.white.opacity(0.1)
        case .breathing: Color.white.opacity(0.1)
        case .darkZen: Color.white.opacity(0.05)
        case .softDawn: Color.black.opacity(0.1)
        case .obsidian: Color.white.opacity(0.05)
        }
    }

    var streakSuccess: Color {
        switch self {
        case .liquidGlass: .green
        case .breathing: .green
        case .darkZen: .green.opacity(0.85)
        case .softDawn: .green
        case .obsidian: .green.opacity(0.85)
        }
    }

    var streakActiveMeditation: Color {
        switch self {
        case .liquidGlass: .purple
        case .breathing: .purple
        case .darkZen: .purple.opacity(0.85)
        case .softDawn: .purple
        case .obsidian: .purple.opacity(0.85)
        }
    }

    var streakActiveNote: Color {
        switch self {
        case .liquidGlass: .blue
        case .breathing: .blue
        case .darkZen: .blue.opacity(0.85)
        case .softDawn: .blue
        case .obsidian: .blue.opacity(0.85)
        }
    }

    var streakMuted: Color {
        switch self {
        case .liquidGlass: .gray.opacity(0.35)
        case .breathing: .gray.opacity(0.35)
        case .darkZen: .white.opacity(0.2)
        case .softDawn: .gray.opacity(0.35)
        case .obsidian: .white.opacity(0.2)
        }
    }

    var streakCellBackground: Color {
        switch self {
        case .liquidGlass: Color.white.opacity(0.06)
        case .breathing: Color.white.opacity(0.06)
        case .darkZen: Color.white.opacity(0.06)
        case .softDawn: Color.black.opacity(0.04)
        case .obsidian: Color.white.opacity(0.06)
        }
    }

    /// Color scheme для системних елементів (wheel picker тощо) — dark для темних тем.
    var colorScheme: ColorScheme {
        switch self {
        case .darkZen, .obsidian: .dark
        case .liquidGlass, .breathing, .softDawn: .light
        }
    }

    /// Текст на акцентних кнопках — завжди світлий поверх стабільного акцентного фону.
    var buttonText: Color {
        switch self {
        case .darkZen, .obsidian: .white
        case .liquidGlass, .breathing, .softDawn: .white
        }
    }

    /// Непрозорий акцентний фон для кнопок дій (Start Meditation тощо) —
    /// без прозорості, щоб під кнопкою нічого не просвічувало.
    var accentButton: Color {
        switch self {
        case .liquidGlass: .purple
        case .breathing: .purple
        case .softDawn: .purple
        case .darkZen: .purple
        case .obsidian: .purple
        }
    }

    /// Акцентний колір для вкладок, індикаторів та активних елементів навігації.
    var accentColor: Color { accentButton }

    /// Колір для індикаторів стріка (вогонь, бейджі, часткові індикатори).
    var streakIndicator: Color {
        switch self {
        case .liquidGlass, .breathing, .softDawn: .orange
        case .darkZen, .obsidian: .orange.opacity(0.75)
        }
    }

    /// Кольори фаз дихання для анімації.
    func breathingPhaseColor(_ phase: BreathingPhaseType) -> Color {
        switch phase {
        case .inhale: return .cyan
        case .holdAfterInhale: return .blue
        case .exhale: return .purple
        case .holdAfterExhale: return .indigo
        }
    }
}

