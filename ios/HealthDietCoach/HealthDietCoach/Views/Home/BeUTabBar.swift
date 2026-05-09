import SwiftUI

enum BeUAppTab {
    case home
    case plan
    case journey
    case progress
    case me
}

struct BeUTabBar: View {
    let selectedTab: BeUAppTab
    let onSelect: (BeUAppTab) -> Void
    let onOpenMeal: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            tabItem(symbol: "house.fill", title: "Home", tab: .home)
            tabItem(symbol: "sparkles", title: "Plan", tab: .plan)
            actionItem(symbol: "camera.fill", title: "Log Meal", action: onOpenMeal)
            tabItem(symbol: "map.fill", title: "Journey", tab: .journey)
            tabItem(symbol: "chart.line.uptrend.xyaxis", title: "Progress", tab: .progress)
            tabItem(symbol: "person.crop.circle", title: "Profile", tab: .me)
        }
        .padding(10)
        .background(
            Capsule(style: .continuous)
                .fill(BeUTheme.glassBackground)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BeUTheme.glassStroke, lineWidth: 0.5)
                )
                .shadow(color: BeUTheme.shadow, radius: 20, x: 0, y: 10)
        )
    }

    private func tabItem(symbol: String, title: String, tab: BeUAppTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(isActive ? BeUTheme.primaryText : BeUTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.6) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionItem(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(BeUTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}
