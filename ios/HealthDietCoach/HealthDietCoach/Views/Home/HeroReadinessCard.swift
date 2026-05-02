import SwiftUI

struct HeroReadinessCard: View {
    let model: ReadinessCardModel
    let summary: HealthSummary?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        KickerText(text: "Readiness")
                        Text("Listen to your body today")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }

                    Spacer()

                    Text("Last 24h")
                        .font(BeUTheme.helperFont.weight(.semibold))
                        .foregroundColor(BeUTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BeUTheme.glassBackground)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(BeUTheme.glassStroke, lineWidth: 0.5)
                                )
                        )
                }

                HStack(alignment: .center, spacing: 22) {
                    ReadinessRing(
                        score: model.score,
                        status: model.score == nil ? "No data" : model.status,
                        subtitle: subtitle
                    )

                    VStack(spacing: 14) {
                        ForEach(metricRows) { row in
                            MetricRow(
                                symbol: row.symbol,
                                tint: row.tint,
                                value: row.value,
                                label: row.label,
                                compact: true
                            )
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: metricColumnHeight)
                }
            }
            .padding(28)
        }
    }

    private var subtitle: String {
        guard let score = model.score else { return "Awaiting data" }
        switch score {
        case 75...100: return "You're well-rested"
        case 50...74: return "Steady energy"
        default: return "Honor your need to rest"
        }
    }

    private var metricRows: [ReadinessMetricRow] {
        [
            {
                guard let summary, summary.sleepHours > 0 else { return nil }
                return ReadinessMetricRow(
                    symbol: "bed.double.fill",
                    tint: BeUTheme.accent,
                    value: String(format: "%.1fh", summary.sleepHours),
                    label: "Sleep"
                )
            }(),
            summary?.restingHeartRateBpm.map {
                ReadinessMetricRow(symbol: "heart.fill", tint: BeUTheme.lowStatus, value: String(format: "%.0f bpm", $0), label: "Resting HR")
            },
            summary?.hrvMs.map {
                ReadinessMetricRow(symbol: "waveform.path.ecg", tint: BeUTheme.macroFat, value: String(format: "%.0f ms", $0), label: "HRV")
            }
        ]
        .compactMap { $0 }
    }

    private var metricColumnHeight: CGFloat {
        switch metricRows.count {
        case 1: return 120
        case 2: return 132
        default: return 150
        }
    }
}

private struct ReadinessMetricRow: Identifiable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let value: String
    let label: String
}
