import SwiftUI

struct JourneyAchievementsSection: View {
    let snapshot: JourneySnapshot

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                BeUKicker(text: "Unlockables")
                HStack(spacing: 12) {
                    unlockableCard(title: "Badges", value: "\(snapshot.unlockables.badgesUnlocked) / \(snapshot.unlockables.badgesTotal)")
                    unlockableCard(title: "Titles", value: "\(snapshot.unlockables.titlesUnlocked) / \(snapshot.unlockables.titlesTotal)")
                    unlockableCard(title: "Postcards", value: "\(snapshot.unlockables.postcardsUnlocked) / \(snapshot.unlockables.postcardsTotal)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent achievements")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    ForEach(Array(snapshot.achievements.filter(\.unlocked).suffix(3).reversed())) { achievement in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BeUTheme.accent.opacity(0.14))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: achievement.iconName)
                                        .foregroundColor(BeUTheme.accent)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                                Text(achievement.description)
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func unlockableCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
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
