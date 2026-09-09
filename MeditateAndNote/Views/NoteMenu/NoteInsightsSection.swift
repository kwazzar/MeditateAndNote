//
//  NoteInsightsSection.swift
//  MeditateAndNote
//
//  Collapsible insights section for NoteMenu, rendered above the note list.
//  Shows aggregate top themes plus the freshest per-note summaries. Hidden
//  while there are no insights and no pass is running.
//

import SwiftUI

struct NoteInsightsSection: View {
    /// Plain `let`: @Observable reference type owned by AppContainer.
    let viewModel: NoteInsightsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @State private var isExpanded = true

    var body: some View {
        Group {
            if !viewModel.isEmpty {
                content
            }
        }
        // Loads on every appearance, not just when non-empty: a background
        // pass usually finishes while the user is on another tab, so the
        // section must pick up persisted insights when navigating here.
        .task {
            await viewModel.load()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
                header

                if isExpanded {
                    if viewModel.isRefreshing && viewModel.insights.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Analyzing notes…")
                                .font(.subheadline)
                                .foregroundColor(themeManager.current.textPrimary.opacity(0.7))
                        }
                        .padding(.vertical, 4)
                    } else {
                        themesRow
                        ForEach(viewModel.insights.prefix(3)) { insight in
                            insightCard(insight)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(themeManager.current.dividerColor, lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

// MARK: - Subviews

private extension NoteInsightsSection {
    var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text("✨ Insights")
                    .font(.headline)
                    .foregroundColor(themeManager.current.textPrimary)
                Spacer()
                if viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(themeManager.current.textPrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(themeManager.current.textPrimary.opacity(0.6))
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var themesRow: some View {
        if !viewModel.topThemes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.topThemes, id: \.self) { theme in
                        Text(theme)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.current.textPrimary.opacity(0.1))
                            )
                            .foregroundColor(themeManager.current.textPrimary)
                    }
                }
            }
        }
    }

    func insightCard(_ insight: NoteInsight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !insight.summary.isEmpty {
                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.textPrimary)
                    .lineLimit(3)
            }
            if !insight.suggestedTags.isEmpty {
                Text(insight.suggestedTags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundColor(themeManager.current.textPrimary.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Divider()
                .background(themeManager.current.dividerColor)
                .padding(.top, 4)
        }
    }
}
