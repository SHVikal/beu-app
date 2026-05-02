import SwiftUI

struct NourishmentCard: View {
    let progress: DailyNutritionProgress?
    let profile: UserNutritionProfile?
    let meals: [MealLog]
    let onOpenHistory: () -> Void

    var body: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        KickerText(text: "Today's Nourishment")
                        HStack(spacing: 8) {
                            ForEach(MealType.allCases) { type in
                                Circle()
                                    .fill(loggedMealTypes.contains(type) ? BeUTheme.accent : BeUTheme.neutralTrack)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Text(type.shortTitle)
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(loggedMealTypes.contains(type) ? .white : BeUTheme.tertiaryText)
                                    )
                            }
                        }
                    }

                    Spacer()

                    Button("Meal History", action: onOpenHistory)
                        .font(BeUTheme.helperFont.weight(.semibold))
                        .foregroundColor(BeUTheme.accent)
                        .buttonStyle(.plain)
                }

                CalorieBar(
                    consumed: progress?.consumedCalories ?? 0,
                    target: progress?.calorieTarget ?? 0,
                    remaining: progress?.remainingCalories ?? 0
                )

                Divider()
                    .overlay(BeUTheme.divider)

                HStack(spacing: 18) {
                    MacroRing(
                        title: "Protein",
                        value: progress?.consumedProteinGrams ?? 0,
                        target: progress.map { Double($0.proteinTargetGrams) },
                        color: BeUTheme.accent
                    )
                    .frame(maxWidth: .infinity)

                    MacroRing(
                        title: "Carbs",
                        value: progress?.consumedCarbsGrams ?? 0,
                        target: profile?.dailyCarbTargetGrams.map(Double.init),
                        color: BeUTheme.macroCarb
                    )
                    .frame(maxWidth: .infinity)

                    MacroRing(
                        title: "Fat",
                        value: progress?.consumedFatGrams ?? 0,
                        target: profile?.dailyFatTargetGrams.map(Double.init),
                        color: BeUTheme.macroFat
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var loggedMealTypes: Set<MealType> {
        Set(meals.map(\.mealType))
    }
}

private extension MealType {
    var shortTitle: String {
        switch self {
        case .breakfast: return "B"
        case .lunch: return "L"
        case .dinner: return "D"
        case .snack: return "S"
        }
    }
}
