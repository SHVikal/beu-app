import PhotosUI
import SwiftUI

struct BeUKicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(BeUTheme.kickerFont)
            .tracking(1.9)
            .foregroundColor(BeUTheme.tertiaryText)
    }
}

struct BeUTargetBar: View {
    let label: String
    let valueText: String
    let targetText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BeUTheme.secondaryText)
                Spacer()
                Text(valueText)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                Text("/ \(targetText)")
                    .font(.system(size: 13))
                    .foregroundColor(BeUTheme.tertiaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(BeUTheme.hairline)
                        .frame(height: 7)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.65), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(7, proxy.size.width * min(max(progress, 0), 1)), height: 7)
                        .animation(.timingCurve(0.3, 0.7, 0.4, 1, duration: 0.8), value: progress)
                }
            }
            .frame(height: 7)
        }
    }
}

struct BeUStatBlock: View {
    let kicker: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BeUKicker(text: kicker)
            Text(value)
                .font(.system(size: 32, weight: .light))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }
}

struct BeUActionRow: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .stroke(BeUTheme.accent, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(BeUTheme.secondaryText)
            }
            Spacer()
        }
    }
}

struct BeUNudgeCard: View {
    let nudge: DailyNudge

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tileColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconTint)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(nudge.message)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                if let action = nudge.action {
                    Text(action)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(iconTint)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(backgroundColor)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(iconTint)
                .frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var backgroundColor: Color {
        switch nudge.tone {
        case .soft:
            return BeUTheme.accent.opacity(0.10)
        case .alert:
            return BeUTheme.alert.opacity(0.12)
        case .win:
            return BeUTheme.ok.opacity(0.14)
        }
    }

    private var tileColor: Color {
        Color.white.opacity(0.55)
    }

    private var iconTint: Color {
        switch nudge.tone {
        case .soft:
            return BeUTheme.accent
        case .alert:
            return BeUTheme.alert
        case .win:
            return BeUTheme.ok
        }
    }

    private var iconName: String {
        switch nudge.tone {
        case .soft:
            return "sparkles"
        case .alert:
            return "exclamationmark"
        case .win:
            return "checkmark"
        }
    }
}

struct BeULineChart: View {
    let values: [Int]
    let lineColor: Color
    let fillColor: Color

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: points.last?.x ?? proxy.size.width, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [fillColor.opacity(0.35), fillColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 8, height: 8)
                        .position(last)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxValue = max(values.max() ?? 1, 1)
        let stepX = size.width / CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { index, value in
            let progress = CGFloat(value) / CGFloat(maxValue)
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - (progress * (size.height - 8)) - 4
            )
        }
    }
}

struct OnboardShell<Content: View>: View {
    let stepIndex: Int?
    let totalSteps: Int
    let canGoBack: Bool
    let onBack: () -> Void
    let buttonTitle: String
    let buttonEnabled: Bool
    let onContinue: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if canGoBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(BeUTheme.cardBackground))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if let stepIndex {
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index < stepIndex ? BeUTheme.primaryText : BeUTheme.hairline)
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            ScrollView(showsIndicators: false) {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
            }

            Button(action: onContinue) {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(buttonEnabled ? .white : BeUTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(buttonEnabled ? BeUTheme.primaryText : Color.black.opacity(0.12))
                    )
            }
            .disabled(!buttonEnabled)
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(BeUTheme.background.ignoresSafeArea())
    }
}

struct StepInput: View {
    let value: Int
    let unit: String
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(value)")
                .font(.system(size: 22, weight: .light))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
            Text(unit)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(BeUTheme.tertiaryText)

            Spacer()

            VStack(spacing: 4) {
                stepperButton(systemName: "chevron.up") {
                    onChange(min(value + 1, range.upperBound))
                }
                stepperButton(systemName: "chevron.down") {
                    onChange(max(value - 1, range.lowerBound))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
                .frame(width: 32, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }
}

struct PillRow<Value: Hashable & Identifiable>: View {
    let values: [Value]
    let title: (Value) -> String
    let selected: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(values) { value in
                Button(action: { onSelect(value) }) {
                    Text(title(value))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selected.id == value.id ? .white : BeUTheme.primaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected.id == value.id ? BeUTheme.primaryText : BeUTheme.cardBackground)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(BeUTheme.hairline, lineWidth: selected.id == value.id ? 0 : 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct Chip: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : BeUTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? BeUTheme.primaryText : BeUTheme.cardBackground)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(BeUTheme.hairline, lineWidth: isSelected ? 0 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct FieldGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: title)
            content
        }
    }
}
