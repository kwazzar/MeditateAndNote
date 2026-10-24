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
    @State private var showsContents = false
    @State private var showsMarks = false
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
        .sheet(isPresented: $showsContents) {
            TableOfContentsSheet(
                entries: viewModel.tableOfContents,
                currentPage: viewModel.currentPage,
                onSelect: { viewModel.jump(to: $0) }
            )
        }
        .sheet(isPresented: $showsMarks) {
            ReaderMarksSheet(
                marks: viewModel.marks,
                currentPage: viewModel.currentPage,
                onSelect: { mark in
                    if let page = page(for: mark) {
                        viewModel.jump(to: page)
                    }
                },
                onDelete: { mark in
                    Task { await viewModel.deleteMark(mark) }
                }
            )
        }
        .sheet(isPresented: $showsSettings) {
            ReaderSettingsSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Pages

    private func pages(_ paginated: PaginatedBook) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                pageContent(paginated.pages[min(viewModel.currentPage, paginated.pages.count - 1)])
                    .frame(width: proxy.size.width - 40, alignment: .leading)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
            // One handler for the whole page: a tap in the left/right third
            // turns the page, a tap in the center toggles the chrome. A
            // separate overlay would swallow the long press that opens the
            // line actions, so the zones live in this handler instead.
            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                let third = proxy.size.width / 3
                if location.x < third {
                    viewModel.goToPreviousPage()
                } else if location.x > third * 2 {
                    viewModel.goToNextPage()
                } else {
                    showsChrome.toggle()
                }
            }
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
            ForEach(Array(page.lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.system(size: viewModel.fontSize, design: .serif))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contextMenu {
                        Button {
                            Task { await viewModel.createHighlight(line: line, lineIndex: index, asNote: false) }
                        } label: {
                            Label("Highlight", systemImage: "highlighter")
                        }
                        Button {
                            Task { await viewModel.createHighlight(line: line, lineIndex: index, asNote: true) }
                        } label: {
                            Label("Add to notes", systemImage: "note.text")
                        }
                        Button {
                            Task { await viewModel.addBookmark() }
                        } label: {
                            Label("Bookmark this page", systemImage: "bookmark")
                        }
                    }
            }
        }
        .foregroundStyle(readerText)
    }

    /// The page a mark points at, resolved against the current layout.
    private func page(for mark: Bookmark) -> Int? {
        guard let paginated = viewModel.paginated else { return nil }
        return PaginationEngine(measurer: UITextMeasurer(fontSize: viewModel.fontSize))
            .page(of: mark.position, in: paginated)
    }

    // MARK: - Chrome

    // Chrome bars, like the FBReader menu: neutral gray bands over the page,
    // identical in every paper theme.
    private var chromeBackground: Color {
        Color(red: 0.23, green: 0.23, blue: 0.25).opacity(0.95)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
                Spacer()
                Button {
                    showsContents = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.headline)
                }
                Button {
                    showsMarks = true
                    Task { await viewModel.loadMarks() }
                } label: {
                    Image(systemName: "bookmark")
                        .font(.headline)
                }
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.headline)
                }
            }
            .padding()
            .foregroundStyle(Color.white)
            .background(chromeBackground.ignoresSafeArea(edges: .top))

            Spacer()

            HStack(spacing: 12) {
                Text("\(viewModel.currentPage + 1) / \(viewModel.pageCount)")
                // FBReader-style footer: a thin progress bar between the page
                // counter and the clock.
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                TimelineView(.everyMinute) { context in
                    Text(context.date, style: .time)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.85))
            .padding()
            .background(chromeBackground.ignoresSafeArea(edges: .bottom))
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
}
