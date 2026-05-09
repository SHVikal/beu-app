import SwiftUI

struct JourneyBadgesPreviewSection: View {
    let achievements: [JourneyAchievement]
    let onOpenAll: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Badges")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Button("View all", action: onOpenAll)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(featuredBadges.prefix(4))) { achievement in
                    JourneyBadgeTile(achievement: achievement)
                }
            }
        }
    }

    private var featuredBadges: [JourneyAchievement] {
        let sorted = achievements.sorted { lhs, rhs in
            if lhs.unlocked == rhs.unlocked {
                return lhs.title < rhs.title
            }
            return lhs.unlocked && !rhs.unlocked
        }
        return sorted
    }
}

struct JourneyBadgesView: View {
    let achievements: [JourneyAchievement]

    @State private var filter: JourneyBadgeCategory = .all
    @State private var selectedBadge: JourneyAchievement?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Badges")
                    .font(BeUTheme.titleFont)
                    .foregroundColor(BeUTheme.primaryText)

                Text("Track distance, city unlocks, streaks, and big walking days.")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([JourneyBadgeCategory.all, .earned, .locked], id: \.self) { category in
                            Button(action: { filter = category }) {
                                Text(category.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(filter == category ? .white : BeUTheme.primaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(filter == category ? BeUTheme.primaryText : BeUTheme.cardBackground)
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(BeUTheme.cardBorder, lineWidth: filter == category ? 0 : 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredAchievements) { achievement in
                        Button(action: { selectedBadge = achievement }) {
                            JourneyBadgeTile(achievement: achievement, showDescription: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(BeUTheme.background.ignoresSafeArea())
        .sheet(item: $selectedBadge) { achievement in
            JourneyBadgeDetailSheet(achievement: achievement)
                .presentationDetents([.medium])
        }
    }

    private var filteredAchievements: [JourneyAchievement] {
        switch filter {
        case .all:
            return achievements.sorted(using: sortComparator)
        case .earned:
            return achievements.filter(\.unlocked).sorted(using: sortComparator)
        case .locked:
            return achievements.filter { !$0.unlocked }.sorted(using: sortComparator)
        default:
            return achievements.sorted(using: sortComparator)
        }
    }

    private var sortComparator: KeyPathComparator<JourneyAchievement> {
        KeyPathComparator(\.title)
    }
}

struct JourneyBadgeTile: View {
    let achievement: JourneyAchievement
    var showDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(achievement.unlocked ? BeUTheme.accent.opacity(0.16) : BeUTheme.neutralTrack)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(achievement.unlocked ? BeUTheme.accent : BeUTheme.tertiaryText)
                    )
                Spacer()
                if achievement.unlocked {
                    Text("Earned")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(BeUTheme.accent)
                } else {
                    Text("\(Int((achievement.progress * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                    .lineLimit(2)
                if showDescription {
                    Text(achievement.description)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(BeUTheme.neutralTrack)
                    Capsule(style: .continuous)
                        .fill(achievement.unlocked ? BeUTheme.accent : BeUTheme.secondaryText.opacity(0.5))
                        .frame(width: max(proxy.size.width * achievement.progress, 8))
                }
            }
            .frame(height: 6)

            Text(achievement.category.label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(BeUTheme.tertiaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(achievement.unlocked ? BeUTheme.cardBackground : BeUTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(achievement.unlocked ? BeUTheme.accent.opacity(0.12) : BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }
}

