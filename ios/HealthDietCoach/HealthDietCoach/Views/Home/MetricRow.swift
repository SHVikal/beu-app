import SwiftUI

struct MetricRow: View {
    let symbol: String
    let tint: Color
    let value: String
    let label: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.13))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tint)
                )

            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(value)
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                Text(label)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.tertiaryText)
            }

            Spacer()
        }
    }
}
