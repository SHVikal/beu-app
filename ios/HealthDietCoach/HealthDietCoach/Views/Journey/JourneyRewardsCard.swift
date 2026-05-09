import SwiftUI

struct JourneyRewardsCard: View {
    let snapshot: JourneySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Explorer Points")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.72))
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(BeUTheme.accentSoft)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.progress.points.formatted())
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Text(snapshot.progress.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.76))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Level \(snapshot.currentLevel.id)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text(snapshot.nextLevel?.title ?? "Top level reached")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(Color.white.opacity(0.58))
                        .multilineTextAlignment(.trailing)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress to next level")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(Color.white.opacity(0.68))
                    Spacer()
                    Text(snapshot.nextLevel.map { "\($0.threshold - snapshot.progress.points) XP left" } ?? "Complete")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(Color.white.opacity(0.68))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [BeUTheme.accentSoft, BeUTheme.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * snapshot.nextLevelProgress, 10))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(hex: "#171116"), Color(hex: "#2E1C24")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
}

