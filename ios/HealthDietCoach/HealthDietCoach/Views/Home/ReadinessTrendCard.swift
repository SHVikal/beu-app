import SwiftUI

struct ReadinessTrendCard: View {
    let summary: ReadinessTrendSummary

    var body: some View {
        NavigationLink {
            ReadinessTrendDetailView(summary: summary)
        } label: {
            BeUCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            KickerText(text: "7-day trend")
                            Text("Readiness")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(BeUTheme.primaryText)
                        }

                        Spacer()

                        Text(summary.trendDirection.capitalized)
                            .font(BeUTheme.helperFont.weight(.semibold))
                            .foregroundColor(trendColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(trendColor.opacity(0.14))
                            )
                    }

                    ReadinessBars(points: summary.points)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.averageScore.map(String.init) ?? "No data")
                                .font(BeUTheme.bigNumber(size: 34))
                                .monospacedDigit()
                                .foregroundColor(BeUTheme.primaryText)
                            Text("Average readiness this week")
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }

                        Spacer()

                        Text("View details")
                            .font(BeUTheme.helperFont.weight(.semibold))
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var trendColor: Color {
        switch summary.trendDirection {
        case "improving":
            return BeUTheme.macroFat
        case "declining":
            return Color(hex: "#D08F8F")
        default:
            return BeUTheme.secondaryText
        }
    }
}

struct ReadinessTrendDetailView: View {
    let summary: ReadinessTrendSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BeUCard {
                    VStack(alignment: .leading, spacing: 18) {
                        KickerText(text: "Readiness trend")
                        Text("Readiness trend")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        ReadinessBars(points: summary.points)
                        Text(summary.summaryMessage)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 16) {
                        KickerText(text: "Weekly summary")
                        summaryMetric("Average score", value: summary.averageScore.map(String.init) ?? "No data")
                        summaryMetric("Highest day", value: summary.highestScore.map(String.init) ?? "No data")
                        summaryMetric("Lowest day", value: summary.lowestScore.map(String.init) ?? "No data")
                        summaryMetric("Trend direction", value: summary.trendDirection.capitalized)
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 16) {
                        KickerText(text: "Daily scores")
                        ForEach(summary.points) { point in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formattedDate(point.date))
                                        .font(BeUTheme.bodyFont.weight(.semibold))
                                        .foregroundColor(BeUTheme.primaryText)
                                    Text(point.status)
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.secondaryText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(point.score.map(String.init) ?? "No data")
                                        .font(.system(size: 18, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(BeUTheme.primaryText)
                                    Text(point.topReason)
                                        .font(BeUTheme.helperFont)
                                        .foregroundColor(BeUTheme.mutedText)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 190, alignment: .trailing)
                                }
                            }
                            if point.id != summary.points.last?.id {
                                Divider().overlay(BeUTheme.divider)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .background(BeUTheme.background.ignoresSafeArea())
        .navigationTitle("Readiness trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryMetric(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
        }
    }

    private func formattedDate(_ isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        guard let date = formatter.date(from: isoDate) else { return isoDate }
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}
