import SwiftUI

struct SummaryCardView: View {
    let summary: HealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Summary")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            Text(summary.date)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("Steps", "\(summary.steps)")
                metric("Active kcal", "\(Int(summary.activeEnergyKcal.rounded()))")
                metric("Workouts", "\(summary.workoutCount)")
                metric("Workout min", "\(Int(summary.workoutMinutes.rounded()))")
                metric("Sleep", "\(String(format: "%.1f", summary.sleepHours)) h")
                metric("HRV", summary.hrvMs.map { "\(String(format: "%.0f", $0)) ms" } ?? "N/A")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: BeUTheme.shadow, radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
