//
//  SearchBar.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI

struct SearchBar: View {
    @FocusState private var isTextFieldFocused: Bool
    @State private var isSearching: Bool = false
    var titleSearch: String
    var searchText: Binding<String>
    var onClose: () -> Void

    var body: some View {
        VStack {
            HStack {
                TextField(titleSearch, text: searchText)
                    .focused($isTextFieldFocused)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 2)
                    .innerStroke(cornerRadius: 8, lineWidth: 2, color: .black, inset: 4)
                    .onTapGesture {
                        isSearching = true
                    }

                if isTextFieldFocused {
                    Button(action: {
                        isTextFieldFocused = false
                        isSearching = false
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.black)
                            .padding()
                    }
                }
            }
            .padding(.horizontal)
        }
        .animation(.easeInOut, value: isTextFieldFocused)
    }
}

struct SearchBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var searchText = ""

        var body: some View {
            SearchBar(titleSearch: "Search items...", searchText: $searchText) {
                // Action when close button is pressed
                print("Search closed")
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits) // Adjust the layout for better visibility in previews
            .padding() // Add padding for aesthetics in preview
    }
}
