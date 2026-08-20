//
//  FloatingToolbar.swift
//  MeditateAndNote
//

import SwiftUI

struct FloatingToolbar: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var isKeyboardVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "bold", title: "Bold")
            toolbarButton(icon: "italic", title: "Italic")
            toolbarButton(icon: "list.bullet", title: "List")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.snappy(duration: 0.25), value: isKeyboardVisible)
    }

    private func toolbarButton(icon: String, title: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
                .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Interactive") {
    struct PreviewWrapper: View {
        @State private var isKeyboardVisible = true

        var body: some View {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.15)
                    .ignoresSafeArea()

                VStack {
                    Button(isKeyboardVisible ? "Hide" : "Show") {
                        isKeyboardVisible.toggle()
                    }
                    Spacer()
                }
                .padding()

                if isKeyboardVisible {
                    FloatingToolbar(isKeyboardVisible: $isKeyboardVisible)
                }
            }
        }
    }
    return PreviewWrapper()
        .environment(ThemeManager())
}
