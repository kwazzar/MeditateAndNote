import SwiftUI

struct MeditationCompletionView: View {
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager

    let meditation: Meditation
    let duration: MeditationDuration

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            headerSection

            infoSection

            Spacer()

            actionButtons
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 24)
        .background(themeManager.current.mainBackground.ignoresSafeArea())
    }
}

// MARK: - Sections

private extension MeditationCompletionView {
    var headerSection: some View {
        VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(themeManager.current.streakSuccess)

            Text("Well Done!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.current.textPrimary)

            Text("You completed your meditation session")
                .font(.body)
                .foregroundStyle(themeManager.current.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    var infoSection: some View {
        VStack(spacing: 12) {
            infoRow(icon: "leaf.fill", label: meditation.title.rawValue)
            infoRow(icon: "wind", label: meditation.breathingStyle.rawValue)
            infoRow(icon: "clock", label: formatDuration(duration.rawValue))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    func infoRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
                .frame(width: 24)

            Text(label)
                .font(.body)
                .foregroundStyle(themeManager.current.textPrimary)

            Spacer()
        }
    }

    var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                router.navigate(to: .push(.newNote))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("Write a Note")
                }
                .font(.headline)
                .foregroundColor(themeManager.current.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeManager.current.accentButton)
                )
            }

            Button(action: {
                router.navigate(to: .tab(.home))
            }) {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundStyle(themeManager.current.textSecondary)
                    .padding(.vertical, 8)
            }
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(mins) min"
        }
        return "\(mins) min \(secs) sec"
    }
}

// MARK: - Preview

struct MeditationCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationCompletionView(
            meditation: Meditation(
                id: "preview",
                title: MeditationTitle("Calm Breath"),
                breathingStyle: .fourSevenEight
            ),
            duration: .fiveMin
        )
        .environment(Router.previewRouter())
        .environment(ThemeManager())
    }
}
