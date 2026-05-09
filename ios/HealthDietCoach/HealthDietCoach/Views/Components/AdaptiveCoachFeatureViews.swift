import SwiftUI

struct NextBestMealCard: View {
    let suggestion: NextBestMealSuggestion
    let isSaved: Bool
    let onLog: () -> Void
    let onSave: () -> Void
    let onAlternatives: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        BeUKicker(text: "Next best meal")
                        Text(suggestion.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text("Portion: \(suggestion.portion)")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("~\(suggestion.estimatedCalories) kcal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text("~\(Int(suggestion.estimatedProteinGrams.rounded()))g protein")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                Text(suggestion.reason)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)

                HStack(spacing: 10) {
                    Button("Log this meal", action: onLog)
                        .buttonStyle(BeUPrimaryButtonStyle())
                    Button("Alternatives", action: onAlternatives)
                        .buttonStyle(BeUSecondaryButtonStyle())
                    Button(isSaved ? "Saved" : "Save") {
                        guard !isSaved else { return }
                        onSave()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSaved ? BeUTheme.tertiaryText : BeUTheme.primaryText)
                }
            }
        }
    }
}

struct MealAlternativesSheet: View {
    let primaryMeal: String
    let alternates: [NextBestMealSuggestion]
    let savedMeals: [SavedMealForLater]
    let onLog: (NextBestMealSuggestion) -> Void
    let onSave: (NextBestMealSuggestion) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Alternatives")
                        .font(BeUTheme.titleFont)
                        .foregroundColor(BeUTheme.primaryText)

                    Text("Other ways to keep the same direction as \(primaryMeal).")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)

                    ForEach(alternates) { alternate in
                        BeUCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alternate.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(BeUTheme.primaryText)
                                        Text("Portion: \(alternate.portion)")
                                            .font(BeUTheme.helperFont)
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("~\(alternate.estimatedCalories) kcal")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(BeUTheme.primaryText)
                                        Text("~\(Int(alternate.estimatedProteinGrams.rounded()))g protein")
                                            .font(BeUTheme.helperFont)
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }
                                }

                                Text(alternate.reason)
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)

                                HStack(spacing: 12) {
                                    Button("Log this meal") {
                                        onLog(alternate)
                                    }
                                    .buttonStyle(BeUSecondaryButtonStyle())

                                    let saved = savedMeals.contains(where: { $0.id == alternate.id })
                                    Button(saved ? "Saved" : "Save") {
                                        guard !saved else { return }
                                        onSave(alternate)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(saved ? BeUTheme.tertiaryText : BeUTheme.primaryText)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(BeUTheme.background.ignoresSafeArea())
        }
    }
}

struct WeeklyReviewView: View {
    let review: WeeklyReview
    let appliedFocusChips: [String]
    let onUseFocus: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                scorecardsGrid
                recommendationCard
                bulletsSection(title: "What went well", items: review.wins)
                bulletsSection(title: "What needs focus", items: review.focus)
                adjustmentsSection
                Button(appliedFocusChips == review.recommendationChips ? "Focus saved" : "Use this focus", action: onUseFocus)
                    .buttonStyle(BeUPrimaryButtonStyle())
                    .disabled(appliedFocusChips == review.recommendationChips)
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(BeUTheme.background.ignoresSafeArea())
    }

    private var heroCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 10) {
                BeUKicker(text: "Weekly review")
                Text(review.headline)
                    .font(BeUTheme.titleFont)
                    .foregroundColor(BeUTheme.primaryText)
                Text(review.weekRangeText)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
                if review.hasEnoughData == false {
                    Text("Log a few more days to unlock your weekly review.")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
    }

    private var scorecardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(review.scorecards) { scorecard in
                BeUCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(scorecard.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BeUTheme.primaryText)
                            Spacer()
                            statusCapsule(scorecard.status)
                        }
                        Text(scorecard.metric)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text(scorecard.insight)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var recommendationCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 10) {
                BeUKicker(text: "BeU weekly recommendation")
                Text(review.recommendationHeadline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                chipWrap(review.recommendationChips)
            }
        }
    }

    private func bulletsSection(title: String, items: [String]) -> some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 10) {
                BeUKicker(text: title)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(BeUTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
        }
    }

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: "Suggested focus next week")
            ForEach(review.adjustments) { adjustment in
                BeUCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(adjustment.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text(adjustment.description)
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
            }
        }
    }

    private func chipWrap(_ chips: [String]) -> some View {
        FlexibleChipWrap(chips: chips)
    }

    private func statusCapsule(_ status: String) -> some View {
        let fill: Color
        let textColor: Color
        switch status {
        case "Strong":
            fill = BeUTheme.ok.opacity(0.14)
            textColor = BeUTheme.ok
        case "Good":
            fill = BeUTheme.accent.opacity(0.16)
            textColor = BeUTheme.primaryText
        case "Moderate":
            fill = BeUTheme.warn.opacity(0.16)
            textColor = BeUTheme.primaryText
        default:
            fill = BeUTheme.alert.opacity(0.14)
            textColor = BeUTheme.alert
        }

        return Text(status)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(fill))
    }
}

struct MealQualityCard: View {
    let result: MealQualityResult

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BeUKicker(text: "Meal quality")
                    Spacer()
                    ratingCapsule
                }
                indicatorMeter
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(result.indicators) { indicator in
                        qualityIndicator(indicator)
                    }
                }
                Text(result.summary)
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.primaryText)
                Text(result.tip)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private var ratingCapsule: some View {
        Text(result.rating)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(BeUTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(BeUTheme.accent.opacity(0.14)))
    }

    private var indicatorMeter: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(index <= result.meter ? BeUTheme.accent : BeUTheme.hairline)
                    .frame(height: 8)
            }
        }
    }

    private func qualityIndicator(_ indicator: MealQualityIndicator) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(indicator.label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text(indicator.status)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }
}

struct MealQualityCompact: View {
    let result: MealQualityResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BeUTheme.accent)
            Text("Meal quality: \(result.rating)")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(BeUTheme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }
}

struct WhatChangedTodayCard: View {
    let delta: DailyDelta
    let onOpenDetail: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 10) {
                BeUKicker(text: "What changed today")
                Text(delta.tldr)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                ForEach(delta.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(BeUTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(bullet)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
                Button("Why this changed", action: onOpenDetail)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }
        }
    }
}

struct WhyThisChangedSheet: View {
    let delta: DailyDelta

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why this changed")
                        .font(BeUTheme.titleFont)
                        .foregroundColor(BeUTheme.primaryText)

                    ForEach(delta.groups) { group in
                        BeUCard {
                            VStack(alignment: .leading, spacing: 10) {
                                BeUKicker(text: group.title)
                                ForEach(group.bullets, id: \.self) { bullet in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(BeUTheme.accent)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 6)
                                        Text(bullet)
                                            .font(BeUTheme.bodyFont)
                                            .foregroundColor(BeUTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(BeUTheme.background.ignoresSafeArea())
        }
    }
}

struct LoggedMealCardView: View {
    let meal: MealLog
    let quality: MealQualityResult?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let isDeleting: Bool
    @State private var showingQuality = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Logged")
                        .font(BeUTheme.helperFont.weight(.semibold))
                        .foregroundColor(BeUTheme.secondaryText)
                    Text(mealSummary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(meal.totalCalories) kcal")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text("\(Int(meal.totalProteinGrams.rounded()))g protein")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }

            if let quality {
                Button {
                    showingQuality = true
                } label: {
                    MealQualityCompact(result: quality)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Button("Edit", action: onEdit)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                    .buttonStyle(.plain)
                Button("Delete", action: onDelete)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.alert)
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showingQuality) {
            if let quality {
                MealQualityCard(result: quality)
                    .padding(16)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var mealSummary: String {
        let names = meal.items.prefix(3).map(\.name)
        if names.isEmpty { return meal.mealType.title }
        let summary = names.joined(separator: ", ")
        return meal.items.count > 3 ? "\(summary)..." : summary
    }
}

private struct FlexibleChipWrap: View {
    let chips: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(BeUTheme.accent.opacity(0.14)))
            }
        }
    }
}
