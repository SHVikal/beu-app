import SwiftUI

struct CalorieBar: View {
    let consumed: Int
    let target: Int
    let remaining: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(consumed)")
                    .font(BeUTheme.bigNumber(size: 38))
                    .monospacedDigit()
                    .tracking(-1.4)
                    .foregroundColor(BeUTheme.primaryText)
                Text("/")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.tertiaryText)
                Text("\(target)")
                    .font(.system(size: 24, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.tertiaryText)
            }

            Text(remaining >= 0 ? "\(remaining) kcal remaining" : "Over by \(abs(remaining)) kcal")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)

            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = target > 0 ? min(max(CGFloat(consumed) / CGFloat(target), 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(BeUTheme.neutralTrack)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BeUTheme.accentSoft, BeUTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}
