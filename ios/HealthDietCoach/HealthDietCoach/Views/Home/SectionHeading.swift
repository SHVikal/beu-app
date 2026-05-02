import SwiftUI

struct SectionHeading: View {
    let kicker: String
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                KickerText(text: kicker)
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }

            Spacer()

            Button(action: action) {
                Text(actionTitle)
                    .font(BeUTheme.helperFont.weight(.semibold))
                    .foregroundColor(BeUTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
