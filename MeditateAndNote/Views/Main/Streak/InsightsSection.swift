//
//  InsightsSection.swift
//  MeditateAndNote
//

import SwiftUI

// MARK: - Insights Section (embeddable in StreakDetailView)

struct InsightsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var router: Router
    let viewModel: InsightsViewModel

    @State private var selectedInsight: StreakInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.recommendations.isEmpty {
                recommendationsBlock
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !viewModel.insights.isEmpty {
                insightsBlock
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: viewModel.insights.count)
        .animation(.snappy(duration: 0.3), value: viewModel.recommendations.count)
        .sheet(item: $selectedInsight) { insight in
            NavigationStack {
                InsightDetailView(insight: insight)
            }
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

    private var insightsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

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

    // MARK: - Action Handling

    private func handleRecommendationAction(_ action: RecommendationAction?) {
        guard let action else { return }
        switch action {
        case .navigateToMeditation:
            router.navigate(to: .tab(.meditations))
        case .navigateToNote:
            router.navigate(to: .push(.newNote))
        case .setReminder:
            router.navigate(to: .push(.settings))
        }
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
                    .foregroundStyle(.blue)

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
        case .risk: return .red
        case .trend: return .green
        case .pattern: return .blue
        case .completion: return .orange
        }
    }

    private var accentColor: Color {
        switch insight.category {
        case .risk: return .red
        case .trend: return .green
        case .pattern: return .blue
        case .completion: return .orange
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
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}
