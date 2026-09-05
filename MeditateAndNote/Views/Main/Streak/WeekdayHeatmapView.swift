//
//  WeekdayHeatmapView.swift
//  MeditateAndNote
//

import SwiftUI

struct WeekdayHeatmapView: View {
    @Environment(ThemeManager.self) private var themeManager
    let data: WeekdayHeatmapData
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(data.days.indices, id: \.self) { index in
                    let day = data.days[index]
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForRate(day.completionRate))
                            .frame(height: 32)
                            .scaleEffect(y: appeared ? 1 : 0, anchor: .bottom)
                            .overlay(
                                Text("\(Int(day.completionRate * 100))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(day.completionRate > 0.4 ? themeManager.current.buttonText : themeManager.current.textSecondary)
                                    .opacity(appeared ? 1 : 0)
                            )

                        Text(day.shortName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(themeManager.current.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.snappy(duration: 0.3).delay(Double(index) * 0.05), value: appeared)
                }
            }
        }
        .onAppear {
            appeared = true
        }
    }

    private func colorForRate(_ rate: Double) -> Color {
        switch rate {
        case 0.75...1.0:
            return themeManager.current.streakSuccess
        case 0.50..<0.75:
            return themeManager.current.streakSuccess.opacity(0.6)
        case 0.25..<0.50:
            return themeManager.current.streakIndicator
        case 0.01..<0.25:
            return themeManager.current.danger.opacity(0.6)
        default:
            return themeManager.current.toolbarBackground
        }
    }
}

// MARK: - Insight Detail View (drill-down)

struct InsightDetailView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    let insight: StreakInsight
    let range: StreakRange
    let weeklyBreakdown: [WeeklyBucket]

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)

                if let heatmap = insight.heatmapData {
                    heatmapDetailSection(heatmap)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.snappy(duration: 0.4).delay(0.1), value: appeared)
                }

                if !weeklyBreakdown.isEmpty {
                    weeklyBreakdownSection
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.snappy(duration: 0.4).delay(0.12), value: appeared)
                }

                if let value = insight.value {
                    valueSection(value)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.snappy(duration: 0.4).delay(0.15), value: appeared)
                }

                messageSection
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.snappy(duration: 0.4).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(themeManager.current.mainBackground.ignoresSafeArea())
        .navigationTitle(insight.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(themeManager.current.textPrimary)

                Text(insight.category.label)
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Heatmap Detail

    private func heatmapDetailSection(_ data: WeekdayHeatmapData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Completion by Day")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.current.textPrimary)

            WeekdayHeatmapView(data: data)

            if let weakest = data.days.min(by: { $0.completionRate < $1.completionRate }),
               weakest.completionRate < 0.5 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.current.streakIndicator)

                    Text("Focus on \(weakest.name)s — your weakest day")
                        .font(.caption)
                        .foregroundStyle(themeManager.current.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Weekly Breakdown (drill-down bars)

    private var weeklyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weekly Completion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeManager.current.textPrimary)

                Spacer()

                Text(range.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(themeManager.current.streakActiveMeditation.opacity(0.18))
                    )
                    .foregroundStyle(themeManager.current.streakActiveMeditation)
            }

            WeeklyBreakdownChart(buckets: weeklyBreakdown, range: range)

            if let best = weeklyBreakdown.max(by: { $0.completionRate < $1.completionRate }),
               best.completionRate > 0 {
                Text("Best week: \(formatWeek(best.weekStart)) — \(Int(best.completionRate * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(themeManager.current.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .animation(.snappy, value: range)
        .animation(.snappy, value: weeklyBreakdown)
    }

    private func formatWeek(_ start: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: start)
    }

    // MARK: - Value Section

    private func valueSection(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeManager.current.textPrimary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.current.toolbarBackground)
                        .frame(height: 8)

                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * min(max(value, 0), 1), height: 8)
                        .animation(.snappy, value: value)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Message

    private var messageSection: some View {
        Text(insight.message)
            .font(.body)
            .foregroundStyle(themeManager.current.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
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

// MARK: - InsightCategory Label Extension

extension InsightCategory {
    var label: String {
        switch self {
        case .completion: return "Completion"
        case .pattern: return "Pattern"
        case .trend: return "Trend"
        case .risk: return "Risk"
        }
    }
}

// MARK: - Weekly Breakdown Chart (drill-down bars)

private struct WeeklyBreakdownChart: View {
    @Environment(ThemeManager.self) private var themeManager
    let buckets: [WeeklyBucket]
    let range: StreakRange

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: barSpacing(for: buckets.count)) {
                ForEach(buckets.indices, id: \.self) { index in
                    bucketView(at: index, in: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: chartHeight)
        .onAppear { appeared = true }
        .animation(.snappy, value: buckets.count)
        .animation(.snappy, value: range)
    }

    private var chartHeight: CGFloat {
        switch range {
        case .last7: return 96
        case .last30: return 96
        case .last90: return 96
        }
    }

    private func barSpacing(for count: Int) -> CGFloat {
        max(2, min(8, CGFloat(48 / max(count, 1))))
    }

    private func bucketView(at index: Int, in height: CGFloat) -> some View {
        let bucket = buckets[index]
        let rate = max(0, min(1, bucket.completionRate))
        let barHeight = height * CGFloat(rate)
        let delay = Double(index) * 0.04

        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor(for: rate))
                .frame(maxWidth: .infinity)
                .frame(height: appeared ? max(4, barHeight) : 4, alignment: .bottom)
                .animation(.snappy(duration: 0.4).delay(delay), value: appeared)
                .animation(.snappy, value: rate)

            Text(shortLabel(for: bucket.weekStart))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(themeManager.current.textSecondary)
        }
    }

    private func barColor(for rate: Double) -> Color {
        switch rate {
        case 0.75...1.0: return themeManager.current.streakSuccess
        case 0.50..<0.75: return themeManager.current.streakSuccess.opacity(0.6)
        case 0.25..<0.50: return themeManager.current.streakIndicator
        case 0.01..<0.25: return themeManager.current.danger.opacity(0.6)
        default: return themeManager.current.toolbarBackground
        }
    }

    private func shortLabel(for weekStart: Date) -> String {
        switch range {
        case .last7: return ""
        case .last30: return "\(calendar.component(.day, from: weekStart))"
        case .last90: return "\(calendar.component(.day, from: weekStart))"
        }
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US")
        return cal
    }
}
