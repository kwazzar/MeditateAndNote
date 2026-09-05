//
//  ReadingView.swift
//  MeditateAndNote
//
//  Created by Quasar on 17.07.2025.
//

import SwiftUI

struct ReadingView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .foregroundStyle(themeManager.current.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.current.mainBackground)
    }
}

struct ReadingView_Previews: PreviewProvider {
    static var previews: some View {
        ReadingView()
            .environment(ThemeManager())
    }
}
