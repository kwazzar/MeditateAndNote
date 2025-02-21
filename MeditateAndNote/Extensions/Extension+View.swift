//
//  Extension+View.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

extension View {
    func innerStroke(cornerRadius: CGFloat = 8, lineWidth: CGFloat = 2, color: Color = .black, inset: CGFloat = 4) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: inset)
                .stroke(color, lineWidth: lineWidth)
        )
    }
}
