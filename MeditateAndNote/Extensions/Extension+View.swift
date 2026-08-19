//
//  Extension+View.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

// MARK: - Custom Tab Bar Environment Key

struct CustomTabBarVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isCustomTabBarVisible: Bool {
        get { self[CustomTabBarVisibleKey.self] }
        set { self[CustomTabBarVisibleKey.self] = newValue }
    }
}

// MARK: - View Helpers

extension View {
    func innerStroke(cornerRadius: CGFloat = 8, lineWidth: CGFloat = 2, color: Color = .black, inset: CGFloat = 4) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: inset)
                .stroke(color, lineWidth: lineWidth)
        )
    }
}
