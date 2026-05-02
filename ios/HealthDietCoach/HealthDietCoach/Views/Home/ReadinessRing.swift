import SwiftUI

struct ReadinessRing: View {
    let score: Int?
    let status: String
    let subtitle: String

    @State private var animatedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(BeUTheme.neutralTrack, lineWidth: 12)

            Canvas { context, size in
                guard animatedProgress > 0 else { return }

                let rect = CGRect(origin: .zero, size: size)
                let insetRect = rect.insetBy(dx: 6, dy: 6)
                let endAngle = Angle.degrees(-90 + (360 * animatedProgress))
                var path = Path()
                path.addArc(
                    center: CGPoint(x: insetRect.midX, y: insetRect.midY),
                    radius: insetRect.width / 2,
                    startAngle: .degrees(-90),
                    endAngle: endAngle,
                    clockwise: false
                )

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [BeUTheme.accentSoft, BeUTheme.accent]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
            }

            VStack(spacing: 6) {
                Text("SCORE")
                    .font(BeUTheme.kickerFont)
                    .tracking(1.6)
                    .foregroundColor(BeUTheme.tertiaryText)

                Text(score.map(String.init) ?? "--")
                    .font(BeUTheme.bigNumber(size: 56))
                    .monospacedDigit()
                    .tracking(-1.6)
                    .foregroundColor(BeUTheme.primaryText)

                Text(subtitle)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Text(status.uppercased())
                    .font(BeUTheme.kickerFont)
                    .tracking(1.3)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(statusColor.opacity(0.12))
                    )
            }
            .padding(.horizontal, 18)
        }
        .frame(width: 158, height: 158)
        .onAppear {
            withAnimation(.linear(duration: 0.8)) {
                animatedProgress = min(max(Double(score ?? 0) / 100, 0), 1)
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.linear(duration: 0.8)) {
                animatedProgress = min(max(Double(newValue ?? 0) / 100, 0), 1)
            }
        }
    }

    private var statusColor: Color {
        switch status.lowercased() {
        case "high":
            return BeUTheme.highStatus
        case "good":
            return BeUTheme.ok
        case "moderate":
            return BeUTheme.moderateStatus
        case "low":
            return BeUTheme.lowStatus
        case "limited_data":
            return BeUTheme.secondaryText
        default:
            return BeUTheme.secondaryText
        }
    }
}
