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
        HStack(spacing: 10) {
            tabButton(.notes, systemImage: "note.text", title: "Notes")
            tabButton(.home, systemImage: "house", title: "Home")
            tabButton(.meditations, systemImage: "leaf", title: "Meditations")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
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
            .padding(.vertical, 6)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? themeManager.current.accentColor.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
