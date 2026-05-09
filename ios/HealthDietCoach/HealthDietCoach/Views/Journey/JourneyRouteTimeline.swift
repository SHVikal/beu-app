import SwiftUI

struct JourneyRouteTimeline: View {
    let snapshot: JourneySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                let routeWidth = max(proxy.size.width - 28, 1)
                let markerOffset = max(min(routeWidth * snapshot.progressPercent, routeWidth), 0)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 4)
                        .offset(x: 14)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BeUTheme.accentSoft, BeUTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: markerOffset, height: 4)
                        .offset(x: 14)

                    HStack(spacing: 0) {
                        ForEach(snapshot.challenge.milestones) { milestone in
                            timelineNode(for: milestone)
                            if milestone.id != snapshot.challenge.milestones.last?.id {
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Circle()
                        .fill(BeUTheme.accent)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "figure.walk")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: max(min(markerOffset + 4, proxy.size.width - 20), 0), y: -8)
                }
            }
            .frame(height: 48)

            HStack {
                ForEach(snapshot.challenge.milestones) { milestone in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.city)
                            .font(.system(size: 11, weight: snapshot.currentMilestone.id == milestone.id ? .bold : .semibold))
                            .foregroundColor(snapshot.currentMilestone.id == milestone.id ? .white : Color.white.opacity(0.72))
                        Text("\(Int(milestone.distanceKm)) km")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.52))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func timelineNode(for milestone: JourneyMilestone) -> some View {
        let completed = snapshot.progress.totalDistanceKm >= milestone.distanceKm
        let current = snapshot.currentMilestone.id == milestone.id

        return ZStack {
            Circle()
                .fill(completed ? BeUTheme.accent : Color.white.opacity(0.14))
                .frame(width: current ? 28 : 20, height: current ? 28 : 20)
            Image(systemName: milestone.symbolName)
                .font(.system(size: current ? 12 : 10, weight: .bold))
                .foregroundColor(completed ? .white : Color.white.opacity(0.78))
        }
    }
}

