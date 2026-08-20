//
//  MainTheme.swift
//  MeditateAndNote
//
//  Created by kwazzar on 22.07.2026.
//

import SwiftUI

enum MainTheme: String {
    case liquidGlass, breathing, softDawn, darkZen, obsidian
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
}

