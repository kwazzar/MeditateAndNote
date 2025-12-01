//
//  NoteMenu.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI
#warning("Note and Reading")
#warning("searcBar note")

enum Menu {
    case Note
    case Reading
}

struct NoteMenu: View {
    @StateObject var viewModel: NoteMenuViewModel
    @StateObject var uiState: NotesUIState
    @StateObject var searchState: SearchState

    init(viewModel: NoteMenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _uiState = StateObject(wrappedValue: viewModel.uiState)
        _searchState = StateObject(wrappedValue: viewModel.searchState)
    }


    var body: some View {
        VStack {

            HStack {
                searchBar


            }
            Spacer()
            NoteCardsView(noteCards: viewModel.last10Notes)
                .padding(.bottom, 12)

        }
        .background(Color.blue)

    }
}

private extension NoteMenu {
    var searchBar: some View {
        VStack {
            
        }
//SearchBar(titleSearch: "note find", searchText: <#T##Binding<String>#>, onClose: <#T##() -> Void#>)

//        SearchBar(
//            titleSearch: "Search items...",
//            searchText: Binding(
//                get: { viewModel.searchState.searchText.text },
//                set: { newText in
//                    let query = SearchQuery(text: newText)
//                    viewModel.searchState.searchText = query
//                    viewModel.searchState.updateFilteredItems(for: query)
//                }
//            ),
//            onClose: {
//                viewModel.searchState.resetSearch()
//            }
//        )
    }
}

struct NoteMenu_Previews: PreviewProvider {
    static var previews: some View {
        NoteMenu(viewModel: AppContainer().makeNoteMenuView())
    }
}
