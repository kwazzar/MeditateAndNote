//
//  NoteMenu.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI
#warning("Note and Reading")

enum Menu {
    case Note
    case Reading
}

struct NoteMenu: View {
#warning("delete white background and change to liquid")
    @State var viewModel: NoteMenuViewModel
    @State var uiState: NotesUIState
    @State var searchState: SearchState
    
    @State private var isScrolling = false
    
    init(viewModel: NoteMenuViewModel) {
        self.viewModel = viewModel
        self.uiState = viewModel.uiState
        self.searchState = viewModel.searchState
    }
    
    var body: some View {
        VStack {
            HStack {
                searchBar
                    .padding(.horizontal)
            }
            
            GeometryReader { geo in
                ScrollDetector(isScrolling: $isScrolling) {
                    LazyVStack {
                        ForEach(displayedNotes) { note in
                            NoteCard(note: note, toNoteAction: { _ in })
                        }
                    }
                    .padding()
                }
                .frame(height: geo.size.height - 52)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            .overlay(alignment: .bottomTrailing) {
                addNoteButton
                    .opacity(isScrolling ? 0 : 1)
                    .scaleEffect(isScrolling ? 0.6 : 1)
                    .padding(.bottom, 60)
                    .padding(.trailing, 12)
                    .allowsHitTesting(!isScrolling)
                    .animation(.easeInOut(duration: 0.2),
                               value: isScrolling)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .background(Color.blue)
    }
}

private extension NoteMenu {
    var displayedNotes: [Note] {
        viewModel.searchState.filteredItems
    }
    
    var addNoteButton: some View {
        Button(action: {
            // TODO: Implement add note action
        }) {
            
            HStack {
                Text("Add Note")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(height: 40)
                    .padding(5)
            }
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(0.3),
                            radius: 5)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.black,
                                  lineWidth: 2)
            )
        }
    }
    
    var searchBar: some View {
        SearchBar(
            titleSearch: "Search notes...",
            searchText: Binding(
                get: { viewModel.searchState.searchText.text },
                set: { newText in
                    let query = SearchQuery(text: newText)
                    viewModel.searchState.searchText = query
                    viewModel.searchState.updateFilteredItems(for: query)
                }
            ),
            onClose: {
                viewModel.searchState.resetSearch()
            }
        )
    }
}

struct NoteMenu_Previews: PreviewProvider {
    static var previews: some View {
        NoteMenu(viewModel: AppContainer().makeNoteMenuView())
    }
}
