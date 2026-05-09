import SwiftUI

struct JourneyStatsCard: View {
    let snapshot: JourneySnapshot

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                BeUKicker(text: "Trail stats")
                HStack(spacing: 12) {
                    statBlock(
                        title: "Walked today",
                        value: String(format: "%.1f km", snapshot.todayLog?.distanceKm ?? 0),
                        subtitle: "\((snapshot.todayLog?.steps ?? 0).formatted()) steps"
                    )
                    statBlock(
                        title: "Total walked",
                        value: String(format: "%.0f km", snapshot.progress.totalDistanceKm),
                        subtitle: "Keep going, you’re amazing!"
                    )
                }
                HStack(spacing: 12) {
                    statBlock(
                        title: "Current stop",
                        value: snapshot.currentMilestone.city,
                        subtitle: "You are here"
                    )
                    statBlock(
                        title: "Up next",
                        value: snapshot.nextMilestone?.city ?? "Berlin",
                        subtitle: snapshot.nextMilestone == nil ? "Challenge complete" : "\(Int(snapshot.distanceRemainingKm.rounded())) km left"
                    )
                }
            }
        }
    }

    private func statBlock(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(BeUTheme.kickerFont)
                .foregroundColor(BeUTheme.tertiaryText)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }
}
