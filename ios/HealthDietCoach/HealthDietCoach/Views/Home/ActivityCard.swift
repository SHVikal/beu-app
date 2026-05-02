import SwiftUI

struct ActivityCard: View {
    let summary: HealthSummary?

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                KickerText(text: "Activity")
                HStack(spacing: 14) {
                    activityMetric(
                        title: "Steps",
                        value: summary.map { "\($0.steps)" } ?? "—",
                        subtitle: "Today"
                    )
                    activityMetric(
                        title: "Active kcal",
                        value: summary.map { "\(Int($0.activeEnergyKcal.rounded()))" } ?? "—",
                        subtitle: "Burned"
                    )
                }
            }
        }
    }

    private func activityMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BeUTheme.helperFont.weight(.semibold))
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.bigNumber(size: 34))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BeUTheme.background)
        )
    }
}
