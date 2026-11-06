//
//  CustomTabBar.swift
//  MeditateAndNote
//
//  Created by kwazzar on 02.09.2026.
//

import SwiftUI

struct CustomTabBar: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedTab: TabDestination
    
    var body: some View {
        HStack(spacing: 2) {
            tabButton(.notes, systemImage: "note.text", title: "Notes")
            tabButton(.home, systemImage: "house", title: "Home")
            tabButton(.meditations, systemImage: "leaf", title: "Meditations")
            tabButton(.reading, systemImage: "book", title: "Reading")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .gray.opacity(0.3), radius: 5)
        )
        .overlay(
            Capsule()
                .strokeBorder(themeManager.current.dividerColor, lineWidth: 1)
        )
    }
    
    private func tabButton(_ tab: TabDestination,
                           systemImage: String,
                           title: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundColor(isSelected ? themeManager.current.accentColor : themeManager.current.textSecondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isSelected ? themeManager.current.accentColor.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
