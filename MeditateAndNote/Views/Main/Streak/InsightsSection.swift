//
//  InsightsSection.swift
//  MeditateAndNote
//

import SwiftUI

// MARK: - Insights Section (embeddable in StreakDetailView)

struct InsightsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(ReminderManager.self) private var reminderManager
    @Environment(Router.self) private var router
    let viewModel: InsightsViewModel

    @State private var selectedRange: StreakRange
    @State private var selectedInsight: StreakInsight?

    init(viewModel: InsightsViewModel) {
        self.viewModel = viewModel
        _selectedRange = State(initialValue: viewModel.selectedRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.recommendations.isEmpty {
                recommendationsBlock
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            insightsHeader

            if !viewModel.insights.isEmpty {
                insightCards
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: selectedRange) { _, newValue in
            viewModel.selectedRange = newValue
        }
        .animation(.snappy(duration: 0.3), value: viewModel.insights.count)
        .animation(.snappy(duration: 0.3), value: viewModel.recommendations.count)
        .animation(.snappy(duration: 0.3), value: viewModel.selectedRange)
        .sheet(item: $selectedInsight) { insight in
            NavigationStack {
                InsightDetailView(
                    insight: insight,
                    range: viewModel.selectedRange,
                    weeklyBreakdown: viewModel.weeklyBreakdown
                )
            }
        }
        .alert("Set Reminder", isPresented: $showReminderAlert) {
            Button("OK") {}
        } message: {
            Text(reminderAlertMessage)
        }
    }

    // MARK: - Recommendations

    private var recommendationsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommendations")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            ForEach(viewModel.recommendations) { rec in
                RecommendationRow(recommendation: rec) {
                    handleRecommendationAction(rec.action)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Insights Grid

    private var insightsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Insights")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeManager.current.textPrimary)

                Text(rangeSubtitle)
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: rangeSubtitle)
            }

            Spacer()

            rangePicker
        }
    }

    private var rangeSubtitle: String {
        let completion = viewModel.insights
            .first(where: { $0.category == .completion })?
            .value
        if let completion {
            return "\(viewModel.selectedRange.title) · \(Int((completion * 100).rounded()))% complete"
        }
        return viewModel.selectedRange.title
    }

    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.insights) { insight in
                if insight.heatmapData != nil {
                    HeatmapInsightRow(insight: insight)
                        .onTapGesture { selectedInsight = insight }
                } else {
                    InsightCard(insight: insight)
                        .onTapGesture { selectedInsight = insight }
                }
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(StreakRange.allCases) { range in
                Text(range.shortLabel).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(themeManager.current.streakActiveMeditation)
    }

    // MARK: - Action Handling

    @State private var showReminderAlert = false
    @State private var reminderAlertMessage = ""

    private func handleRecommendationAction(_ action: RecommendationAction?) {
        guard let action else { return }
        switch action {
        case .navigateToMeditation:
            router.navigate(to: .tab(.meditations))
        case .navigateToNote:
            router.navigate(to: .push(.newNote))
        case .setReminder:
            enableReminderForWeakestDay()
        }
    }

    private func enableReminderForWeakestDay() {
        let weakest = weakestWeekday()
        Task {
            await reminderManager.enableReminder(
                hour: 20,
                minute: 0,
                weekdays: Set(weakest.map { [$0.weekday] } ?? Array(1...7))
            )
            if reminderManager.isAuthorized {
                if let weakest {
                    reminderAlertMessage = "Reminder enabled for \(weakest.name)s at 20:00."
                } else {
                    reminderAlertMessage = "Daily reminder enabled at 20:00."
                }
            } else {
                reminderAlertMessage = "Notifications are turned off. Enable them in Settings to receive reminders."
            }
            showReminderAlert = true
        }
    }

    /// Returns the (weekday, name) pair for the day with the lowest completion
    /// rate from the weekly heatmap, if any.
    private func weakestWeekday() -> (weekday: Int, name: String)? {
        let heatmapDays = viewModel.insights.first { $0.heatmapData != nil }?.heatmapData?.days
        guard let days = heatmapDays,
              let index = days.indices.min(by: { days[$0].completionRate < days[$1].completionRate })
        else { return nil }
        return (index + 1, days[index].name)
    }
}

// MARK: - Heatmap Insight Row (full-width)

private struct HeatmapInsightRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let insight: StreakInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: insight.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor)

                Text(insight.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.textSecondary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            if let heatmap = insight.heatmapData {
                WeekdayHeatmapView(data: heatmap)
            }

            Text(insight.message)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }

    private var iconColor: Color {
        switch insight.category {
        case .risk: return themeManager.current.danger
        case .trend: return themeManager.current.streakSuccess
        case .pattern: return themeManager.current.streakActiveNote
        case .completion: return themeManager.current.streakIndicator
        }
    }
}

// MARK: - Insight Card

private struct InsightCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let insight: StreakInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: insight.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor)

                Text(insight.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            Text(insight.message)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let value = insight.value {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(themeManager.current.toolbarBackground)
                            .frame(height: 4)

                        Capsule()
                            .fill(accentColor)
                            .frame(width: geo.size.width * min(max(value, 0), 1), height: 4)
                            .animation(.snappy, value: value)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }

    private var iconColor: Color {
        switch insight.category {
        case .risk: return themeManager.current.danger
        case .trend: return themeManager.current.streakSuccess
        case .pattern: return themeManager.current.streakActiveNote
        case .completion: return themeManager.current.streakIndicator
        }
    }

    private var accentColor: Color {
        switch insight.category {
        case .risk: return themeManager.current.danger
        case .trend: return themeManager.current.streakSuccess
        case .pattern: return themeManager.current.streakActiveNote
        case .completion: return themeManager.current.streakIndicator
        }
    }
}

// MARK: - Recommendation Row

private struct RecommendationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let recommendation: UserRecommendation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: recommendation.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(priorityColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(themeManager.current.textPrimary)

                    Text(recommendation.message)
                        .font(.caption)
                        .foregroundStyle(themeManager.current.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if recommendation.action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(themeManager.current.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(priorityColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return themeManager.current.danger
        case .medium: return themeManager.current.streakIndicator
        case .low: return themeManager.current.streakActiveNote
        }
    }
}
