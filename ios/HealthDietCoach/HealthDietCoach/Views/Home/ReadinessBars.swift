import SwiftUI

struct ReadinessBars: View {
    let points: [ReadinessTrendPoint]

    private var chartPoints: [ReadinessTrendPoint] {
        Array(points.suffix(7))
    }

    private var maxScore: Double {
        max(Double(chartPoints.compactMap(\.score).max() ?? 100), 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(chartPoints.enumerated()), id: \.element.id) { index, point in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(barColor(for: point, isToday: index == chartPoints.count - 1))
                        .frame(height: barHeight(for: point))

                    Text(shortDay(from: point.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(BeUTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 84, alignment: .bottom)
    }

    private func barHeight(for point: ReadinessTrendPoint) -> CGFloat {
        guard let score = point.score else { return 6 }
        return max(14, CGFloat(Double(score) / maxScore) * 60)
    }

    private func barColor(for point: ReadinessTrendPoint, isToday: Bool) -> Color {
        guard point.score != nil else { return BeUTheme.neutralStub }
        return isToday ? BeUTheme.accent : BeUTheme.accent.opacity(0.33)
    }

    private func shortDay(from isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        guard let date = formatter.date(from: isoDate) else { return "—" }
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
