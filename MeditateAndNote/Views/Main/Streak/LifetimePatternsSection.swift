//
//  LifetimePatternsSection.swift
//  MeditateAndNote
//
//  Lifetime streak insights: distribution, resilience, and weekday
//  break pattern. These three views do not depend on `selectedRange`
//  and stay stable as the user toggles 7D/30D/90D.
//

import SwiftUI

struct LifetimePatternsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    let viewModel: InsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Patterns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            if viewModel.streakLengthDistribution.totalStreaks > 0 {
                StreakDistributionCard(distribution: viewModel.streakLengthDistribution)
            }

            if viewModel.resilience.totalRecoveries > 0 {
                ResilienceCard(resilience: viewModel.resilience)
            }

            if !viewModel.weekdayBreakHeatmap.days.isEmpty {
                BreakPatternCard(heatmap: viewModel.weekdayBreakHeatmap)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Distribution Card

private struct StreakDistributionCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let distribution: StreakLengthDistribution
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.current.accentColor)

                Text("Streak Distribution")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            let maxCount = max(distribution.buckets.map(\.count).max() ?? 1, 1)
            VStack(spacing: 6) {
                ForEach(distribution.buckets.indices, id: \.self) { index in
                    let bucket = distribution.buckets[index]
                    HStack(spacing: 8) {
                        Text(bucket.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(themeManager.current.textSecondary)
                            .frame(width: 72, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(themeManager.current.toolbarBackground)
                                    .frame(height: 8)
                                Capsule()
                                    .fill(themeManager.current.accentColor)
                                    .frame(
                                        width: geo.size.width * (CGFloat(bucket.count) / CGFloat(maxCount)) * (appeared ? 1 : 0),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        Text("\(bucket.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.current.textPrimary)
                            .frame(width: 28, alignment: .trailing)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.snappy(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                }
            }

            Text(distributionSummary)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .onAppear { appeared = true }
    }

    private var distributionSummary: String {
        let total = distribution.totalStreaks
        let median = distribution.medianLength
        if let largest = distribution.buckets.max(by: { $0.count < $1.count }), largest.count > 0 {
            return "\(total) streaks total. Most common: \(largest.label.lowercased()). Median: \(median) day\(median == 1 ? "" : "s")."
        }
        return "\(total) streaks total."
    }
}

// MARK: - Resilience Card

private struct ResilienceCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let resilience: StreakResilience

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.current.streakActiveMeditation)

                Text("Resilience")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            HStack(spacing: 16) {
                statTile(
                    label: "Avg recovery",
                    value: String(format: "%.1f", resilience.avgRecoveryDays),
                    unit: "days"
                )
                statTile(
                    label: "Longest gap",
                    value: "\(resilience.longestRecoveryDays)",
                    unit: "days"
                )
                statTile(
                    label: "Recoveries",
                    value: "\(resilience.totalRecoveries)",
                    unit: nil
                )
            }

            if !resilience.survivalByDay.isEmpty {
                survivalSummary
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }

    private func statTile(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.current.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeManager.current.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var survivalSummary: some View {
        let survival7 = resilience.survivalByDay[7].map { "\(Int($0 * 100))%" } ?? "—"
        let survival14 = resilience.survivalByDay[14].map { "\(Int($0 * 100))%" } ?? "—"
        let survival30 = resilience.survivalByDay[30].map { "\(Int($0 * 100))%" } ?? "—"

        return Text("Survival — 7d: \(survival7), 14d: \(survival14), 30d: \(survival30)")
            .font(.caption)
            .foregroundStyle(themeManager.current.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Break Pattern Card

private struct BreakPatternCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let heatmap: WeekdayHeatmapData
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.current.danger)

                Text("Break Pattern")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            VStack(spacing: 6) {
                ForEach(heatmap.days.indices, id: \.self) { index in
                    let day = heatmap.days[index]
                    HStack(spacing: 8) {
                        Text(day.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(themeManager.current.textSecondary)
                            .frame(width: 32, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(themeManager.current.toolbarBackground)
                                    .frame(height: 8)
                                Capsule()
                                    .fill(themeManager.current.danger)
                                    .frame(
                                        width: geo.size.width * CGFloat(day.breakRate) * (appeared ? 1 : 0),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(day.breakRate * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.current.textPrimary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.snappy(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                }
            }

            Text(breakSummary)
                .font(.caption)
                .foregroundStyle(themeManager.current.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .onAppear { appeared = true }
    }

    private var breakSummary: String {
        guard let worst = heatmap.days.max(by: { $0.breakRate < $1.breakRate }), worst.breakRate > 0 else {
            return "No breaks recorded yet."
        }
        return "\(worst.name)s account for \(Int(worst.breakRate * 100))% of streak breaks."
    }
}
