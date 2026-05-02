import SwiftUI

struct MacroRing: View {
    let title: String
    let value: Double
    let target: Double?
    let color: Color
    var unit: String = "g"
    var showsOneDecimal: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(BeUTheme.neutralTrack, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(valueLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(BeUTheme.primaryText)
                    Text(targetLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BeUTheme.tertiaryText)
                }
            }
            .frame(width: 64, height: 64)

            Text(title)
                .font(BeUTheme.helperFont.weight(.semibold))
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    private var progress: CGFloat {
        guard let target, target > 0 else { return 0 }
        return min(max(CGFloat(value) / CGFloat(target), 0), 1)
    }

    private var valueLabel: String {
        if showsOneDecimal {
            return value.formatted(.number.precision(.fractionLength(1)))
        }
        return "\(Int(value.rounded()))"
    }

    private var targetLabel: String {
        guard let target else { return unit }
        if showsOneDecimal {
            return "/\(target.formatted(.number.precision(.fractionLength(1))))\(unit)"
        }
        return "/\(Int(target.rounded()))\(unit)"
    }
}
