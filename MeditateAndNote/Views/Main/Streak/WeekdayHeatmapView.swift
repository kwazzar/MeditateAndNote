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
                                    .foregroundStyle(day.completionRate > 0.4 ? .white : themeManager.current.textSecondary)
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
            return .green
        case 0.50..<0.75:
            return .green.opacity(0.6)
        case 0.25..<0.50:
            return .orange
        case 0.01..<0.25:
            return .red.opacity(0.6)
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
                        .foregroundStyle(.orange)

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
        case .risk: return .red
        case .trend: return .green
        case .pattern: return .blue
        case .completion: return .orange
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
