//
//  NoteEditorView.swift
//  MeditateAndNote
//

import SwiftUI

struct NoteEditorView: View {
    @State var viewModel: NoteEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @FocusState private var isEditorFocused: Bool
    @State private var isKeyboardVisible = false
    @State private var showDeleteConfirmation = false
    @State private var safeInsets: UIEdgeInsets = .zero
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                editorBody
                if viewModel.showAIDraftBar {
                    aiDraftBar
                }
                // ponytail: FloatingToolbar (bold/italic/list) has no
                // actions wired, so it is not rendered. Render it in the
                // stack, never as a ZStack overlay — an overlay covered
                // the AI bar. Needs an AttributedString editor to be real.
            }
        }
        .onAppear {
            registerKeyboard()
            safeInsets = Self.readSafeInsets()
            DispatchQueue.main.async {
                safeInsets = Self.readSafeInsets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            safeInsets = Self.readSafeInsets()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                safeInsets = Self.readSafeInsets()
            }
        }
        .onDisappear { unregisterKeyboard() }
        .onChange(of: viewModel.title) { _, _ in viewModel.onTextChanged() }
        .onChange(of: viewModel.body) { _, _ in viewModel.onTextChanged() }
        .alert("Delete note?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.delete()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

private extension NoteEditorView {
    // MARK: - AI Draft Bottom Bar

    @ViewBuilder
    var aiDraftBar: some View {
        if let vm = viewModel.aiDraftViewModel {
            aiDraftBarContent(vm)
        }
    }

    @ViewBuilder
    func aiDraftBarContent(_ vm: NoteAIDraftViewModel) -> some View {
        VStack(spacing: 8) {
            if vm.uiState == .loading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating suggestions…")
                        .font(.caption)
                        .foregroundStyle(themeManager.current.textSecondary)
                }
                .frame(maxWidth: .infinity)
            } else if !vm.sessions.isEmpty {
                ForEach(vm.sessions) { session in
                    let acceptedIDs = Set(vm.acceptedSuggestions.map { $0.id })
                    let pending = session.suggestions.filter { !acceptedIDs.contains($0.id) }
                    if !pending.isEmpty {
                        Text(vm.canAccept ? "Proposals" : "Questions")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(themeManager.current.textSecondary)
                            .padding(.horizontal, 4)
                        ForEach(pending) { suggestion in
                            inlineSuggestionRow(suggestion, vm: vm, state: .pending)
                        }
                    }

                    let accepted = vm.acceptedSuggestions.filter { accepted in
                        session.suggestions.contains(where: { $0.id == accepted.id })
                    }
                    if !accepted.isEmpty {
                        Text("Accepted")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(themeManager.current.textSecondary)
                            .padding(.horizontal, 4)
                        ForEach(accepted) { suggestion in
                            inlineSuggestionRow(suggestion, vm: vm, state: .accepted)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if vm.canAccept, vm.hasPending {
                        Button {
                            Task { await vm.acceptAll(from: vm.sessions.first!) }
                        } label: {
                            Label("Accept All", systemImage: "checkmark.all")
                                .font(.caption.weight(.semibold))
                        }
                    }

                    if vm.canTransfer {
                        Button {
                            viewModel.transferAccepted()
                        } label: {
                            Label("Transfer (\(vm.acceptedSuggestions.count))", systemImage: "arrow.right.circle.fill")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(themeManager.current.editorBackground, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, isKeyboardVisible ? 0 : 8)
    }

    func inlineSuggestionRow(_ suggestion: AISuggestion, vm: NoteAIDraftViewModel, state: SuggestionState) -> some View {
        HStack(spacing: 8) {
            Text(suggestion.text)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(1)

            Spacer()

            // Order matters: an ungrounded row is still `.pending`, so the
            // accepted check must not fall through and offer Remove for it —
            // rejecting a never-accepted suggestion is a no-op that looks
            // like a dead button.
            if state == .accepted {
                Button {
                    Task { await vm.reject(suggestion, from: vm.sessions.first!) }
                } label: {
                    Label("Remove", systemImage: "xmark.circle")
                        .font(.caption2.weight(.semibold))
                }
            } else if vm.canAccept {
                Button {
                    Task { await vm.accept(suggestion, from: vm.sessions.first!) }
                } label: {
                    Label("Accept", systemImage: "plus.circle")
                        .font(.caption2.weight(.semibold))
                }
            }
        }
        .padding(8)
        .background(
            state == .accepted
                ? themeManager.current.accentColor.opacity(0.15)
                : themeManager.current.editorBackground,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    // MARK: - Safe Area

    private static func readSafeInsets() -> UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?
            .safeAreaInsets ?? .zero
    }

    // MARK: - Top Bar
    var topBar: some View {
        HStack {
            Button(action: {
                Task { await viewModel.save() }
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.current.iconPrimary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("noteEditorBackButton")
            Spacer()

            Button(action: {
                Task {
                    if viewModel.isDirty {
                        await viewModel.save()
                    }
                    await viewModel.startAIDraft()
                }
            }) {
                if viewModel.isAIDraftGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(themeManager.current.iconPrimary)
            .frame(width: 36, height: 36)
            .disabled(viewModel.isAIDraftGenerating)
            .accessibilityIdentifier("aiDraftButton")

            if !viewModel.isNewNote {
                SwiftUI.Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.current.iconPrimary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, isLandscape ? 22 : 6)
        .padding(.leading, safeInsets.left)
        .padding(.trailing, safeInsets.right)
        .frame(height: 44 + (isLandscape ? 22 : 6))
    }

    // MARK: - Editor
    var editorBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $viewModel.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(themeManager.current.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Divider()
                .overlay(themeManager.current.dividerColor)
                .padding(.horizontal, 0)

            ZStack(alignment: .topLeading) {
                if viewModel.body.isEmpty {
                    Text("Start writing...")
                        .font(.body)
                        .foregroundStyle(themeManager.current.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.body)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(themeManager.current.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focused($isEditorFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            isEditorFocused = true
        }
    }

    // MARK: - Keyboard
    func registerKeyboard() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil, queue: .main
        ) { _ in
            withAnimation(.snappy(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil, queue: .main
        ) { _ in
            withAnimation(.snappy(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
    }

    func unregisterKeyboard() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
}

enum SuggestionState {
    case pending
    case accepted
}

#Preview("Portrait", traits: .portrait) {
    NoteEditorView(viewModel: AppContainer().makeNoteEditorViewModel())
        .environment(ThemeManager())
}

#Preview("Landscape", traits: .landscapeLeft) {
    NoteEditorView(viewModel: AppContainer().makeNoteEditorViewModel())
        .environment(ThemeManager())
}

