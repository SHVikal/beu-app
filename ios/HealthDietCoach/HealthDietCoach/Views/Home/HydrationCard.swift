import SwiftUI

struct HydrationCard: View {
    let current: Double
    let target: Double

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        KickerText(text: "Hydration")
                        Text("\(String(format: "%.1f", current))/\(String(format: "%.1f", target))")
                            .font(BeUTheme.bigNumber(size: 30))
                            .monospacedDigit()
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<8, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index < filledBars ? BeUTheme.accent : BeUTheme.neutralTrack)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private var filledBars: Int {
        guard target > 0 else { return 0 }
        return min(8, max(0, Int((current / target * 8).rounded(.down))))
    }
}
