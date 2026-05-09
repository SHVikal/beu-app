import SwiftUI

struct JourneyCityCardsCarousel: View {
    let snapshot: JourneySnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                cityCard(
                    label: "Current stop",
                    milestone: snapshot.currentMilestone,
                    status: "You are here",
                    accent: true,
                    locked: false
                )

                if let next = snapshot.nextMilestone {
                    cityCard(
                        label: "Up next",
                        milestone: next,
                        status: "\(Int(max(next.distanceKm - snapshot.progress.totalDistanceKm, 0).rounded())) km to go",
                        accent: false,
                        locked: true
                    )
                }

                if let nextNext = snapshot.nextNextMilestone {
                    cityCard(
                        label: "Next stop",
                        milestone: nextNext,
                        status: "Locked for now",
                        accent: false,
                        locked: true
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func cityCard(label: String, milestone: JourneyMilestone, status: String, accent: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(label):")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BeUTheme.tertiaryText)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(BeUTheme.tertiaryText)
                } else {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                }
            }

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: accent ? [Color.black, Color(hex: "#2E1D22")] : [BeUTheme.surface, BeUTheme.cardBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 126)
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom) {
                        Image(systemName: milestone.symbolName)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(accent ? BeUTheme.accentSoft : BeUTheme.accent)
                        Spacer()
                        Circle()
                            .fill((accent ? BeUTheme.accent : BeUTheme.cardBackground).opacity(0.18))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "airplane")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(accent ? BeUTheme.accentSoft : BeUTheme.primaryText)
                            )
                    }
                    .padding(18)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent ? Color.white.opacity(0.08) : BeUTheme.cardBorder, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.city)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(BeUTheme.primaryText)
                Text(milestone.country)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
                Text(status)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(accent ? BeUTheme.accent : BeUTheme.secondaryText)
            }
        }
        .padding(18)
        .frame(width: 268, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: BeUTheme.shadow, radius: 14, x: 0, y: 4)
    }
}

