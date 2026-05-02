import SwiftUI

struct LogMealCTA: View {
    let action: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                KickerText(text: "Log a meal")

                Button(action: action) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(BeUTheme.buttonText)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Log a meal")
                                .font(BeUTheme.buttonFont)
                                .foregroundColor(BeUTheme.buttonText)
                            Text("Snap a photo, we’ll do the rest")
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundColor(BeUTheme.buttonText.opacity(0.75))
                        }

                        Spacer()

                        Circle()
                            .fill(BeUTheme.accent)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(BeUTheme.primaryText)
                            )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(hex: "#1A1A1A"))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
