import SwiftUI

struct JourneyBadgeDetailSheet: View {
    let achievement: JourneyAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Circle()
                    .fill(achievement.unlocked ? BeUTheme.accent.opacity(0.16) : BeUTheme.neutralTrack)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(achievement.unlocked ? BeUTheme.accent : BeUTheme.tertiaryText)
                    )
                Spacer()
                Text(achievement.unlocked ? "Unlocked" : "Locked")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(achievement.unlocked ? BeUTheme.accent : BeUTheme.secondaryText)
            }

            Text(achievement.title)
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)

            Text(achievement.description)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)

            BeUFormCard {
                detailRow("Unlock condition", achievement.unlockCondition)
                detailRow("Progress", "\(Int((achievement.progress * 100).rounded()))%")
                detailRow("Unlocked on", achievement.unlockedAt ?? "Not unlocked yet")
            }

            Spacer()
        }
        .padding(20)
        .background(BeUTheme.background.ignoresSafeArea())
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BeUTheme.kickerFont)
                .foregroundColor(BeUTheme.tertiaryText)
            Text(value)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.primaryText)
        }
    }
}

