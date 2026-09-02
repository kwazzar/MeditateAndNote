//
//  CustomTabBar.swift
//  MeditateAndNote
//
//  Created by kwazzar on 02.09.2026.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: TabDestination
    
    var body: some View {
        HStack(spacing: 32) {
            tabButton(.notes, systemImage: "note.text", title: "Notes")
            tabButton(.home, systemImage: "house", title: "Home")
            tabButton(.meditations, systemImage: "leaf", title: "Meditations")
        }
        .padding(.horizontal, 16)
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
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
