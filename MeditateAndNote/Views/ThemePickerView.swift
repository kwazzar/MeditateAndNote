//
//  ThemePickerView.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager

    let allThemes: [MainTheme] = [.liquidGlass, .breathing, .softDawn, .darkZen]

    var body: some View {
        List(allThemes, id: \.self) { theme in
            Button {
                themeManager.current = theme
            } label: {
                HStack {
                    Text(theme.rawValue.capitalized)
                    Spacer()
                    if theme == themeManager.current {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}
