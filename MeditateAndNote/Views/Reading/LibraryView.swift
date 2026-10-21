//
//  LibraryView.swift
//  MeditateAndNote
//
//  Book library: cover grid, import from Files, per-book progress.
//

import SwiftUI
import UniformTypeIdentifiers
import MeditateAndNoteCore

struct LibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(Router.self) private var router
    @State private var viewModel: LibraryViewModel
    @State private var showsImporter = false

    init(viewModel: LibraryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            themeManager.current.mainBackground

            if viewModel.library.isEmpty {
                emptyState
            } else {
                bookGrid
            }

            VStack {
                HStack {
                    Text("Library")
                        .font(.title2.bold())
                        .foregroundStyle(themeManager.current.textPrimary)
                    Spacer()
                    Button {
                        showsImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                            .foregroundStyle(themeManager.current.textPrimary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                Spacer()
            }
        }
        .task {
            await viewModel.load()
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: Self.importableTypes,
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task { await viewModel.importBook(from: url) }
            }
        }
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { viewModel.importErrorMessage != nil },
                set: { if !$0 { viewModel.importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.importErrorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.current.textSecondary)
            Text("No books yet")
                .font(.headline)
                .foregroundStyle(themeManager.current.textPrimary)
            Text("Import .fb2, .epub or .txt files to start reading")
                .font(.subheadline)
                .foregroundStyle(themeManager.current.textSecondary)
            Button("Import book") {
                showsImporter = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 16)],
                spacing: 20
            ) {
                ForEach(viewModel.library) { book in
                    LibraryBookCell(
                        book: book,
                        coverData: viewModel.covers[book.id],
                        theme: themeManager.current,
                        openAction: {
                            router.present(fullScreen: .reader(bookId: book.id))
                        },
                        deleteAction: {
                            Task { await viewModel.delete(book) }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 70)
            .padding(.bottom, 120)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private static var importableTypes: [UTType] {
        var types: [UTType] = [.text, .data]
        if let fb2 = UTType(filenameExtension: "fb2") { types.append(fb2) }
        if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
        return types
    }
}

// MARK: - Book cell

private struct LibraryBookCell: View {
    let book: Book
    let coverData: Data?
    let theme: MainTheme
    let openAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.toolbarBackground)
                    if let coverData, let image = UIImage(data: coverData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(String(book.title.prefix(1)))
                            .font(.title.bold())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .aspectRatio(0.7, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(book.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                if let author = book.author {
                    Text(author)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: deleteAction) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
