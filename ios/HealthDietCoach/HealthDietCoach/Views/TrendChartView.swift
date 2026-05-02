import SwiftUI

struct TrendChartView: View {
    let summaries: [HealthSummary]

    private var maxSteps: Double {
        max(Double(summaries.map(\.steps).max() ?? 1), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.headline)
                .foregroundColor(BeUTheme.primaryText)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(summaries) { summary in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(BeUTheme.accentPink.gradient)
                            .frame(height: max(20, (Double(summary.steps) / maxSteps) * 120))
                        Text(shortDay(summary.date))
                            .font(.caption2)
                            .foregroundStyle(BeUTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160, alignment: .bottom)

            Text("Bars represent daily step totals for the last 7 days.")
                .font(.caption)
                .foregroundStyle(BeUTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: BeUTheme.shadow, radius: 14, x: 0, y: 8)
    }

    private func shortDay(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
