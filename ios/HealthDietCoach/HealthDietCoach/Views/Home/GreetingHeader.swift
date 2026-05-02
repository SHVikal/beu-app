import SwiftUI

struct GreetingHeader: View {
    let dateLabel: String
    let firstName: String
    let onBellTap: () -> Void
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(dateLabel)
                    .font(BeUTheme.kickerFont)
                    .tracking(1.5)
                    .foregroundColor(BeUTheme.secondaryText)

                Spacer()

                HStack(spacing: 8) {
                    circleButton(icon: "bell", action: onBellTap)
                    Button(action: onAvatarTap) {
                        Circle()
                            .fill(BeUTheme.glassBackground)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(firstName.prefix(1)).uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                            )
                            .overlay(
                                Circle().stroke(BeUTheme.cardBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Good morning, \(firstName)")
                .font(BeUTheme.greetingHeroFont)
                .tracking(-0.75)
                .foregroundColor(BeUTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("A gentle start to your day")
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.black.opacity(0.04))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                )
        }
        .buttonStyle(.plain)
    }
}
