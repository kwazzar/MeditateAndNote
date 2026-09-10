//
//  NoteAIDraftSheet.swift
//  MeditateAndNote
//
//  "Help me write" sheet: prompt field, generate button, suggestions list.
//  Injects chosen suggestions back into the editor via NoteAIDraftViewModel's
//  onInsert callback.
//

import SwiftUI

struct NoteAIDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State var viewModel: NoteAIDraftViewModel
    @State private var promptText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.current.mainBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    promptField
                    content
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Help me write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear {
                viewModel.sheetWillDismiss()
            }
        }
    }

    private var promptField: some View {
        HStack(spacing: 10) {
            TextField("What do you need ideas for?", text: $promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(1...3)

            Button {
                Task { await viewModel.start(instructions: promptText) }
            } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(themeManager.current.iconPrimary)
            }
            .disabled(viewModel.uiState == .loading)
        }
        .padding(12)
        .background(themeManager.current.editorBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState {
        case .idle:
            placeholder

        case .loading:
            loadingView

        case .ready:
            suggestionsList

        case .unavailable:
            unavailableView

        case .failed(let error):
            errorView(error)
        }
    }

    private var placeholder: some View {
        ContentUnavailableView(
            "Ask for a spark of inspiration",
            systemImage: "lightbulb",
            description: Text("Your note stays private. Suggestions are generated on your device.")
        )
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Preparing suggestions…")
                .font(.footnote)
                .foregroundStyle(themeManager.current.textSecondary)
            Text("First run can take a little longer.")
                .font(.caption2)
                .foregroundStyle(themeManager.current.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.sessions) { session in
                    ForEach(session.suggestions) { suggestion in
                        suggestionRow(suggestion, session: session)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func suggestionRow(_ suggestion: AISuggestion, session: AIDraftSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.text)
                .font(.body)
                .foregroundStyle(themeManager.current.textPrimary)

            if !suggestion.rationale.isEmpty {
                Text(suggestion.rationale)
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            Button {
                viewModel.insert(suggestion, from: session)
                dismiss()
            } label: {
                Label("Insert", systemImage: "plus.circle")
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.current.editorBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "AI isn't available here",
                systemImage: "exclamationmark.triangle",
                description: Text("Your device doesn't support on-device AI right now. If this is your first run, the model may still be downloading — try again in a bit.")
            )
            retryButton
        }
    }

    private func errorView(_ error: AIDraftError) -> some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Couldn't generate ideas",
                systemImage: "wifi.exclamationmark",
                description: Text(errorDescription(error))
            )
            retryButton
        }
    }

    /// Re-runs generation with the current prompt. The sparkles button up top
    /// does the same, but a terminal state needs a discoverable way out —
    /// otherwise users sit on the error screen (observed in manual QA).
    private var retryButton: some View {
        Button {
            Task { await viewModel.start(instructions: promptText) }
        } label: {
            Label("Try again", systemImage: "arrow.clockwise")
                .font(.footnote.weight(.semibold))
        }
        .disabled(viewModel.uiState == .loading)
    }

    private func errorDescription(_ error: AIDraftError) -> String {
        switch error {
        case .noContext: return "The note is empty — add a little text first."
        case .rateLimited: return "You've used today's limit. Try again tomorrow."
        case .providerUnavailable: return "AI isn't available right now."
        case .emptyResponse: return "No ideas came back — try a clearer request."
        case .contextTooLong: return "The note is too long for a single request."
        case .cancelled: return "Generation was cancelled."
        }
    }
}