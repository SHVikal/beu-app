import SwiftUI

struct JourneyUnlockablesSection: View {
    let snapshot: JourneySnapshot
    let onOpenBadges: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Unlockables")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Button("See badges", action: onOpenBadges)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }

            HStack(spacing: 12) {
                unlockableCard(icon: "seal.fill", title: "Badges", value: "\(snapshot.unlockables.badgesUnlocked)/\(snapshot.unlockables.badgesTotal)", accent: BeUTheme.accent)
                unlockableCard(icon: "text.badge.checkmark", title: "Titles", value: "\(snapshot.unlockables.titlesUnlocked)/\(snapshot.unlockables.titlesTotal)", accent: BeUTheme.warn)
                unlockableCard(icon: "mail.stack.fill", title: "Postcards", value: "\(snapshot.unlockables.postcardsUnlocked)/\(snapshot.unlockables.postcardsTotal)", accent: BeUTheme.ok)
            }
        }
    }

    private func unlockableCard(icon: String, title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(accent)
                )
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }
}

