//
//  BreathingAnimationStyle.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation

/// Which animation renders during a meditation session. A domain value object
/// so the persisted `AnimationSettings` (Application layer) never has to
/// depend on a presentation type.
enum BreathingAnimationStyle: String, CaseIterable {
    case rings
    case path
}