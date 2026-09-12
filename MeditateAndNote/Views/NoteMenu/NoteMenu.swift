//
//  NoteMenu.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

struct NoteMenu: View {
    @State var viewModel: NoteMenuViewModel
    @State var searchState: SearchState
    /// Plain `let`, not `@State`: the VM is an @Observable reference type
    /// owned by AppContainer — the view only reads it, so the latest passed
    /// value must always win (no first-render staleness).
    let insightsViewModel: NoteInsightsViewModel?
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager

    @State private var isScrolling = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    init(viewModel: NoteMenuViewModel, insightsViewModel: NoteInsightsViewModel? = nil) {
        self.viewModel = viewModel
        self.searchState = viewModel.searchState
        self.insightsViewModel = insightsViewModel
    }
    
    var body: some View {
        VStack {
            HStack {
                searchBar
                    .padding(.horizontal)
            }
            .padding(.top, isLandscape ? 0 : 0)
            .safeAreaPadding(.top, isLandscape ? 24 : 0)
            
            GeometryReader { geo in
                ScrollDetector(isScrolling: $isScrolling) {
                    LazyVStack {
                        if let insightsViewModel {
                            NoteInsightsSection(viewModel: insightsViewModel)
                        }
                        ForEach(displayedNotes) { note in
                            NoteCard(
                                note: note,
                                toNoteAction: { note in
                                    router.navigate(to: .push(.noteDetails(noteId: note.id)))
                                }
                            )
                        }
                    }
                    .padding()
                }
                .frame(height: max(0, geo.size.height - 52))
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: HomeLayout.contentWidth)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomTrailing) {
            addNoteButton
                .opacity(isScrolling ? 0 : 1)
                .scaleEffect(isScrolling ? 0.6 : 1)
                .padding(.bottom, isLandscape ? 52 : 60)
                .padding(.trailing, 26)
                .allowsHitTesting(!isScrolling)
                .animation(.easeInOut(duration: 0.2),
                           value: isScrolling)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .background(themeManager.current.mainBackground)
    }
}

private extension NoteMenu {
    var displayedNotes: [Note] {
        viewModel.searchState.filteredItems
    }
    
    var addNoteButton: some View {
        Button(action: {
            router.navigate(to: .push(.newNote))
        }) {
            
            HStack {
                Text("Add Note")
                    .font(.headline)
                    .foregroundColor(themeManager.current.textPrimary)
                    .frame(height: 40)
                    .padding(5)
            }
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .gray.opacity(0.3),
                            radius: 5)
            )
            .overlay(
                Capsule()
                    .strokeBorder(themeManager.current.dividerColor,
                                  lineWidth: 1)
            )
        }
    }
    
    var searchBar: some View {
        SearchBar(
            titleSearch: "Search notes...",
            searchText: Binding(
                get: { viewModel.searchState.searchText.text },
                set: { newText in
                    viewModel.searchState.searchText = SearchQuery(text: newText)
                }
            ),
            onClose: {
                viewModel.searchState.resetSearch()
            }
        )
    }
}

#Preview("Portrait Preview", traits: .portrait) {
    NoteMenu(viewModel: AppContainer().makeNoteMenuViewModel())
        .environment(ThemeManager())
        .environment(Router.previewRouter())
}

#Preview("Landscape Preview", traits: .landscapeLeft) {
    NoteMenu(viewModel: AppContainer().makeNoteMenuViewModel())
        .environment(ThemeManager())
        .environment(Router.previewRouter())
}
