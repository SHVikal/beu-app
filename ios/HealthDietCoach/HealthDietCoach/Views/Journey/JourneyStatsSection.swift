import SwiftUI

struct JourneyStatsSection: View {
    let snapshot: JourneySnapshot

    var body: some View {
        HStack(spacing: 14) {
            statCard(
                title: "Walked today",
                value: String(format: "%.1f km", snapshot.todayLog?.distanceKm ?? 0),
                subtitle: "\((snapshot.todayLog?.steps ?? 0).formatted()) steps",
                progress: min(max(Double(snapshot.mission.currentSteps) / Double(max(snapshot.mission.stepTarget, 1)), 0), 1),
                footer: "Daily goal: \(String(format: "%.1f", dailyGoalKm)) km"
            )

            statCard(
                title: "Total walked this year",
                value: String(format: "%.0f km", snapshot.progress.totalDistanceKm),
                subtitle: "Keep going, you're amazing!",
                progress: snapshot.progressPercent,
                footer: "\(Int(snapshot.distanceRemainingKm.rounded())) km left"
            )
        }
    }

    private var dailyGoalKm: Double {
        (Double(snapshot.mission.stepTarget) * snapshot.stepLengthMeters) / 1000.0
    }

    private func statCard(title: String, value: String, subtitle: String, progress: Double, footer: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(BeUTheme.tertiaryText)
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(BeUTheme.primaryText)
                .monospacedDigit()
            Text(subtitle)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(BeUTheme.neutralTrack)
                    Capsule(style: .continuous)
                        .fill(BeUTheme.accent)
                        .frame(width: max(proxy.size.width * progress, 10))
                }
            }
            .frame(height: 8)

            Text(footer)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.tertiaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: BeUTheme.shadow, radius: 10, x: 0, y: 3)
    }
}

