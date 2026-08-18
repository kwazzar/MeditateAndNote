//
//  MeditateButtonComponents.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI

extension MainTheme {
    var meditateButtonStyle: MeditateThemeButtonStyle {
        MeditateThemeButtonStyle(theme: self)
    }
}

struct MeditateThemeButtonStyle: ButtonStyle {
    let theme: MainTheme

    func makeBody(configuration: Configuration) -> some View {
        switch theme {
        case .liquidGlass:
            configuration.label

        case .breathing:
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)

        case .softDawn:
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)

        case .darkZen:
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .shadow(
                    color: .white.opacity(configuration.isPressed ? 0.4 : 0.0),
                    radius: configuration.isPressed ? 16 : 0
                )
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        
        case .obsidian:
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct MeditateButtonIcon: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                    .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan, .blue, .purple.opacity(0.8)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    Image(systemName: "wind")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(.white)
                )
                .shadow(color: .blue.opacity(0.35), radius: 24, y: 8)
        }
    }
}
