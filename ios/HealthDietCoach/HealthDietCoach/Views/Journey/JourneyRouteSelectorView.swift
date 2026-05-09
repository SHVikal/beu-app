import SwiftUI

struct JourneyRouteSelectorView: View {
    let challenge: JourneyChallenge
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose your journey")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Button("Change", action: onTap)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }

            Button(action: onTap) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BeUTheme.accentSoft, BeUTheme.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(BeUTheme.primaryText)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text("\(Int(challenge.totalDistanceKm)) km • \(challenge.milestones.count) stops")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                        Text(challenge.subtitle)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.tertiaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(BeUTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                        )
                )
                .shadow(color: BeUTheme.shadow, radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct JourneyRouteSelectorSheet: View {
    let challenges: [JourneyChallenge]
    let selectedChallenge: JourneyChallenge
    let onSelect: (JourneyChallenge) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose your journey")
                    .font(BeUTheme.titleFont)
                    .foregroundColor(BeUTheme.primaryText)

                Text("Each route keeps its own progress, points, and unlocks.")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)

                ForEach(challenges) { challenge in
                    Button(action: { onSelect(challenge) }) {
                        HStack(alignment: .top, spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(challenge.id == selectedChallenge.id ? BeUTheme.accent : BeUTheme.accentSoft)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: challenge.id == selectedChallenge.id ? "mappin.circle.fill" : "map")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(challenge.id == selectedChallenge.id ? .white : BeUTheme.primaryText)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(challenge.title)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Spacer()
                                    if challenge.id == selectedChallenge.id {
                                        Text("Selected")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(BeUTheme.accent)
                                    }
                                }
                                Text("\(Int(challenge.totalDistanceKm)) km • \(challenge.milestones.map(\.city).joined(separator: " → "))")
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                                    .lineLimit(2)
                                Text(challenge.subtitle)
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.tertiaryText)
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(BeUTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(challenge.id == selectedChallenge.id ? BeUTheme.accent.opacity(0.45) : BeUTheme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(BeUTheme.background.ignoresSafeArea())
        }
    }
}

