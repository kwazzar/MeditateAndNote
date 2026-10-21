//
//  ReaderSheets.swift
//  MeditateAndNote
//
//  The reader's two lists: the table of contents and the reader's marks
//  (page bookmarks and passage highlights).
//

import SwiftUI
import MeditateAndNoteCore

// MARK: - Table of contents

struct TableOfContentsSheet: View {
    let entries: [ReaderViewModel.ChapterEntry]
    let currentPage: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    Button {
                        onSelect(entry.page)
                        dismiss()
                    } label: {
                        HStack {
                            Text(entry.title)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Spacer()
                            Text("\(entry.page + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Marks (bookmarks + highlights)

struct ReaderMarksSheet: View {
    let marks: [Bookmark]
    let currentPage: Int
    let onSelect: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if marks.isEmpty {
                    ContentUnavailableView(
                        "No bookmarks yet",
                        systemImage: "bookmark",
                        description: Text("Long-press a line to highlight it, or add a bookmark for this page.")
                    )
                }
                ForEach(marks) { mark in
                    Button {
                        onSelect(mark)
                        dismiss()
                    } label: {
                        row(for: mark)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            onDelete(mark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for mark: Bookmark) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: mark.isHighlight ? "highlighter" : "bookmark")
                .foregroundStyle(mark.isHighlight ? Color.accentColor : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                if let text = mark.text {
                    Text(text)
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    Text("Page \(mark.position.chapterIndex + 1)")
                        .font(.subheadline)
                }
                Text(mark.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if mark.noteID != nil {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
