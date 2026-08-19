//
//  NoteCard.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct NoteCard: View {
    let note: Note
    let toNoteAction: (Note) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter
    }
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                cardContent
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            } else {
                cardContent
                    .background(liquidGlassFallback)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
    }
}

private extension NoteCard {
    var cardContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .frame(height: 120)
            
            HStack {
                Text(dateFormatter.string(from: note.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                Text(note.title)
                    .font(.headline)
                Spacer()
                
                Button {
                    toNoteAction(note)
                } label: {
                    HStack {
                        Text("Read")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.15)),
                alignment: .top
            )
        }
    }
    
    var liquidGlassFallback: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
}
