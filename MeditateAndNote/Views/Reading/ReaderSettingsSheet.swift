//
//  ReaderSettingsSheet.swift
//  MeditateAndNote
//
//  Reader appearance controls: font size and paper theme.
//

import SwiftUI

struct ReaderSettingsSheet: View {
    @Bindable var viewModel: ReaderViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reading mode")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    ForEach([false, true], id: \.self) { mode in
                        Button {
                            viewModel.scrollMode = mode
                        } label: {
                            Text(mode ? "Scroll" : "Pages")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.scrollMode == mode
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15)
                                )
                                .foregroundColor(viewModel.scrollMode == mode ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Font size")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 16) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(
                        value: Binding(
                            get: { viewModel.fontSize },
                            set: { viewModel.fontSize = $0 }
                        ),
                        in: ReaderSettings.fontSizeRange,
                        step: 1
                    )
                    Image(systemName: "textformat.size.larger")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Paper")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    ForEach(ReaderTheme.allCases) { theme in
                        Button {
                            viewModel.theme = theme
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(theme.background)
                                    .overlay(
                                        Circle().stroke(
                                            viewModel.theme == theme ? Color.accentColor : .clear,
                                            lineWidth: 2
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                Text(theme.title)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .presentationDragIndicator(.visible)
    }
}
