//
//  ConcentricRing.swift
//  MeditateAndNote
//
//  Created by Quasar on 07.08.2025.
//

import SwiftUI

struct ConcentricRing: View {
    let index: Int
    let currentPhase: BreathingPhase?
    let phaseProgress: Double
    let breathingColor: Color

    private var baseSize: CGFloat { 120 + CGFloat(index * 30) }
    private var animationDelay: Double { Double(index) * 0.2 }

    var body: some View {
        Circle()
            .stroke(
                breathingColor.opacity(ringOpacity),
                lineWidth: ringLineWidth
            )
            .frame(width: ringSize, height: ringSize)
            .animation(
                .easeInOut(duration: animationDuration)
                .delay(animationDelay),
                value: phaseProgress
            )
            .animation(.easeInOut(duration: 0.3), value: breathingColor)
    }

    private var ringSize: CGFloat {
        guard let currentPhase = currentPhase else { return baseSize }

        let expansionFactor: CGFloat = 1.0 + (0.3 * CGFloat(index + 1))

        switch currentPhase.type {
        case .inhale:
            let progress = CGFloat(phaseProgress)
            return baseSize + (baseSize * expansionFactor - baseSize) * progress
        case .exhale:
            let progress = CGFloat(1.0 - phaseProgress)
            return baseSize + (baseSize * expansionFactor - baseSize) * progress
        case .holdAfterInhale:
            return baseSize * expansionFactor
        case .holdAfterExhale:
            return baseSize
        }
    }

    private var ringOpacity: Double {
        guard let currentPhase = currentPhase else { return 0.3 }

        let baseOpacity = 0.8 - (Double(index) * 0.15)

        switch currentPhase.type {
        case .inhale:
            return baseOpacity * (0.3 + 0.7 * phaseProgress)
        case .exhale:
            return baseOpacity * (1.0 - 0.7 * phaseProgress)
        case .holdAfterInhale:
            return baseOpacity
        case .holdAfterExhale:
            return baseOpacity * 0.3
        }
    }

    private var ringLineWidth: CGFloat {
        guard let currentPhase = currentPhase else { return 2 }

        let baseWidth: CGFloat = 3
        
        switch currentPhase.type {
        case .inhale:
            return baseWidth + CGFloat(phaseProgress) * 2
        case .exhale:
            return baseWidth + CGFloat(1.0 - phaseProgress) * 2
        case .holdAfterInhale:
            return baseWidth + 2
        case .holdAfterExhale:
            return baseWidth
        }
    }

    private var animationDuration: Double {
        guard let currentPhase = currentPhase else { return 1.0 }
        return currentPhase.duration * 0.8
    }
}
