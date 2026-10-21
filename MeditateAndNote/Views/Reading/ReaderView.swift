//
//  ReaderView.swift
//  MeditateAndNote
//
//  Paginated book reader: tap zones turn pages, center tap toggles chrome,
//  settings sheet adjusts font size and paper theme.
//

import SwiftUI
import MeditateAndNoteCore

struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSettings = false
    @State private var showsChrome = false
    @State private var lastSizeClass: UserInterfaceSizeClass?

    init(viewModel: ReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.loadFailed {
                failureState
            } else if let paginated = viewModel.paginated {
                pages(paginated)
            } else {
                ProgressView()
            }

            if showsChrome {
                chrome
            }
        }
        .background(readerBackground.ignoresSafeArea())
                .statusBarHidden(!showsChrome)
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.persistPosition()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.persistPosition()
            }
        }
        .sheet(isPresented: $showsSettings) {
            ReaderSettingsSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Pages

    private func pages(_ paginated: PaginatedBook) -> some View {
        GeometryReader { proxy in
            ZStack {
                pageContent(paginated.pages[min(viewModel.currentPage, paginated.pages.count - 1)])
                    .frame(width: proxy.size.width - 48)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                // Tap zones: left/right turn, center toggles chrome.
                HStack(spacing: 0) {
                    tapZone { viewModel.goToPreviousPage() }
                    tapZone { showsChrome.toggle() }
                    tapZone { viewModel.goToNextPage() }
                }
            }
            .contentShape(Rectangle())
            .onChange(of: proxy.size) { _, newSize in
                // Re-paginate when the usable area changes (rotation).
                if lastSizeClass == nil {
                    lastSizeClass = proxy.size.height > proxy.size.width ? .regular : .compact
                } else {
                    let vertical = newSize.height > newSize.width
                    let sizeClass: UserInterfaceSizeClass? = vertical ? .regular : .compact
                    if sizeClass != lastSizeClass {
                        lastSizeClass = sizeClass
                        viewModel.repaginateKeepingPosition()
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                if value.translation.width < -40 {
                    viewModel.goToNextPage()
                } else if value.translation.width > 40 {
                    viewModel.goToPreviousPage()
                }
            }
        )
    }

    private func pageContent(_ page: PaginatedBook.Page) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(page.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: viewModel.fontSize, design: .serif))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(readerText)
    }

    private func tapZone(_ action: @escaping () -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
                Spacer()
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.headline)
                }
            }
            .padding()
            .foregroundStyle(readerText)

            Spacer()

            HStack {
                Text("\(viewModel.currentPage + 1) / \(viewModel.pageCount)")
                Spacer()
                Text("\(Int(viewModel.progress * 100))%")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(readerSecondary)
            .padding()
        }
    }

    // MARK: - Failure

    private var failureState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text("Could not open the book")
                .font(.headline)
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(readerText)
    }

    // MARK: - Theme helpers

    private var readerBackground: Color {
        viewModel.theme.background
    }

    private var readerText: Color {
        viewModel.theme.text
    }

    private var readerSecondary: Color {
        viewModel.theme.secondaryText
    }
}
