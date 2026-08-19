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
    
    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                editorBody
            }
            
            VStack {
                Spacer()
                if isKeyboardVisible {
                    FloatingToolbar(isKeyboardVisible: $isKeyboardVisible)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear { registerKeyboard() }
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
            Spacer()
            
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
        .padding(.horizontal, 12)
        .frame(height: 44)
    }
    
    // MARK: - Editor
    var editorBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $viewModel.title)
                .font(.system(size: 28, weight: .bold, design: .serif))
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

struct NoteEditor_Previews: PreviewProvider {
    static var previews: some View {
        NoteEditorView(viewModel: AppContainer().makeNoteEditorViewModel())
            .environment(ThemeManager())
    }
}
