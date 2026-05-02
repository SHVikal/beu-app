import SwiftUI

struct PermissionView: View {
    let action: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 42))
                .foregroundColor(BeUTheme.accent)

            Text("Connect Apple Health")
                .font(.largeTitle.bold())
                .foregroundColor(BeUTheme.primaryText)

            Text("BeU reads steps, active energy, workouts, sleep, resting heart rate, HRV, weight, and height to create daily summaries. The app sends only normalized daily totals to the backend for nutrition guidance.")
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)

            Text("Privacy and Safety")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            Text("This MVP does not diagnose or treat medical conditions. For pregnancy, diabetes, eating disorders, or any medical concern, consult a qualified healthcare professional.")
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)

            Button {
                Task {
                    await action()
                }
            } label: {
                Text("Allow Health Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeUPrimaryButtonStyle())
        }
        .padding(24)
        .background(BeUTheme.background.ignoresSafeArea())
    }
}
