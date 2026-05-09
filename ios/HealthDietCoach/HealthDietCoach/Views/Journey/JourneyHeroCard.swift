import SwiftUI

struct JourneyHeroCard: View {
    let snapshot: JourneySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(snapshot.challenge.sourceCity) to \(snapshot.challenge.destinationCity) Challenge")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                Text(snapshot.didCompleteChallenge ? "You reached \(snapshot.challenge.destinationCity). Challenge complete." : snapshot.challenge.subtitle)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(Color.white.opacity(0.78))
            }

            JourneyRouteTimeline(snapshot: snapshot)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f km", snapshot.progress.totalDistanceKm))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("of \(Int(snapshot.challenge.totalDistanceKm).formatted()) km completed")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(Color.white.opacity(0.72))
                }

                GeometryReader { proxy in
                    let progressWidth = max(proxy.size.width * snapshot.progressPercent, 16)

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 10)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [BeUTheme.accentSoft, BeUTheme.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 10)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(hex: "#2A1820"), Color(hex: "#432634")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
}

