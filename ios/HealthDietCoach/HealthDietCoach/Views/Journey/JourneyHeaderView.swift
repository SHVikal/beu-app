import SwiftUI

struct JourneyHeaderView: View {
    let onOpenRoutes: () -> Void
    let onOpenRewards: () -> Void

    var body: some View {
        HStack {
            iconButton(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .onTapGesture(perform: onOpenRoutes)

            Spacer()

            Text("Travel Trail")
                .font(BeUTheme.greetingHeroFont)
                .foregroundColor(BeUTheme.primaryText)

            Spacer()

            iconButton(systemName: "gift.fill")
                .onTapGesture(perform: onOpenRewards)
        }
    }

    private func iconButton(systemName: String) -> some View {
        Circle()
            .fill(BeUTheme.accentSoft.opacity(0.8))
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            )
            .overlay(
                Circle()
                    .stroke(BeUTheme.cardBorder, lineWidth: 0.5)
            )
    }
}

