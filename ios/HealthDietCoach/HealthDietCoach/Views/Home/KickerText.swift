import SwiftUI

struct KickerText: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(BeUTheme.kickerFont)
            .tracking(1.9)
            .foregroundColor(BeUTheme.secondaryText)
    }
}
