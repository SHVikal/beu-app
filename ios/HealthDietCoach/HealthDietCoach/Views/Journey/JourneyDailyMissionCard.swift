import SwiftUI

struct JourneyDailyMissionCard: View {
    let mission: JourneyMission

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily mission")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Text("\(mission.rewardPoints) XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BeUTheme.accent)
            }

            Text(mission.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)

            HStack {
                Text("\(mission.currentSteps.formatted()) / \(mission.stepTarget.formatted()) steps")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Text(progressLabel)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(BeUTheme.neutralTrack)
                        .frame(height: 10)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BeUTheme.accentSoft, BeUTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * progress, 10), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(20)
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

    private var progress: Double {
        min(max(Double(mission.currentSteps) / Double(max(mission.stepTarget, 1)), 0), 1)
    }

    private var progressLabel: String {
        let percent = Int((progress * 100).rounded())
        return "\(percent)% complete"
    }
}
