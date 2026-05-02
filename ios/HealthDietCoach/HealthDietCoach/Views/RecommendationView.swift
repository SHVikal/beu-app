import SwiftUI

struct RecommendationView: View {
    let recommendation: DietRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            overviewCard
            nutritionCard
            actionCard
            safetyCard
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recovery Insight")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            Text(recommendation.insightTitle)
                .font(BeUTheme.titleFont)
                .foregroundColor(BeUTheme.primaryText)
            Text(recommendation.summary)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(recommendation.personalizationNote)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.mutedText)

            if !recommendation.focusAreas.isEmpty {
                Text("Focus Areas")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                ForEach(recommendation.focusAreas, id: \.self) { area in
                    Text("• \(area)")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Nutrition")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            detail("Calories", recommendation.suggestedCalorieDirection)
            detail("Protein", recommendation.proteinGuidance)
            detail("Carbs", recommendation.carbGuidance)
            detail("Hydration", recommendation.hydrationGuidance)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Action Plan")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            detail("Next Best Action", recommendation.nextBestAction)
            detail("Recovery", recommendation.recoveryNote)

            Text("Meal Suggestions")
                .font(BeUTheme.sectionTitleFont)
                .foregroundColor(BeUTheme.primaryText)
            ForEach(recommendation.mealSuggestions, id: \.self) { meal in
                Text("• \(meal)")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }

            if !recommendation.signals.isEmpty {
                Text("Signals Used")
                    .font(BeUTheme.sectionTitleFont)
                    .foregroundColor(BeUTheme.primaryText)
                ForEach(recommendation.signals, id: \.self) { signal in
                    Text("• \(signal)")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var safetyCard: some View {
        Text(recommendation.safetyNote)
            .font(BeUTheme.helperFont)
            .foregroundColor(BeUTheme.mutedText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BeUTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
            Text(value)
                .font(BeUTheme.bodyFont)
                .foregroundColor(BeUTheme.primaryText)
        }
    }
}
