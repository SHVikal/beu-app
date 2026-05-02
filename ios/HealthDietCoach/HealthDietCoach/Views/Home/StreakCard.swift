import SwiftUI

struct StreakCard: View {
    let model: ConsistencyCardModel
    let mealHistory: [MealLog]

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(BeUTheme.accent)
                        KickerText(text: "Consistency")
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(model.currentStreak)")
                            .font(BeUTheme.bigNumber(size: 34))
                            .monospacedDigit()
                            .foregroundColor(BeUTheme.primaryText)
                        Text("days of mindful logging")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(weekDates, id: \.self) { date in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(loggedDates.contains(dateString(date)) ? BeUTheme.accent : BeUTheme.neutralTrack)
                                .frame(maxWidth: .infinity)
                                .frame(height: 18)
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(weekDates, id: \.self) { date in
                            Text(shortDay(date))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(BeUTheme.tertiaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                Text(model.message)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private var loggedDates: Set<String> {
        Set(mealHistory.map(\.date))
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -(6 - offset), to: Date())
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
