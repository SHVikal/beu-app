import Foundation

struct NextBestMealContext: Equatable {
    let calorieTarget: Int
    let proteinTargetGrams: Double
    let caloriesConsumed: Int
    let proteinConsumedGrams: Double
    let mealsLoggedToday: [MealLog]
    let currentHour: Int
    let goalType: String
    let readinessStatus: String?
    let dietPreference: String?
    let healthConditions: [String]
}

struct NextBestMealSuggestion: Equatable, Identifiable, Codable {
    let id: String
    let name: String
    let mealType: String
    let portion: String
    let estimatedCalories: Int
    let estimatedProteinGrams: Double
    let reason: String
    let tags: [String]

    var prefillDescription: String {
        "\(name), portion: \(portion), approx \(estimatedCalories) kcal, \(Int(estimatedProteinGrams.rounded()))g protein"
    }
}

struct NextBestMealResult: Equatable {
    let primary: NextBestMealSuggestion?
    let alternates: [NextBestMealSuggestion]
}

struct SavedMealForLater: Equatable, Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let mealType: String
    let portion: String
    let estimatedCalories: Int
    let estimatedProteinGrams: Double
    let savedAt: String
}

struct WeeklyReviewContext: Equatable {
    struct DaySnapshot: Equatable, Identifiable {
        let id: String
        let date: String
        let caloriesConsumed: Int
        let proteinConsumed: Double
        let steps: Int
        let readinessScore: Int?
        let readinessStatus: String?
        let mealsLogged: Int
        let waterLitres: Double
    }

    let goalType: String
    let calorieTarget: Int
    let proteinTarget: Int
    let stepTarget: Int
    let dailySnapshots: [DaySnapshot]
}

struct WeeklyScorecard: Equatable, Identifiable {
    let id: String
    let title: String
    let status: String
    let metric: String
    let insight: String
}

struct WeeklyAdjustment: Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
}

struct WeeklyReview: Equatable {
    let headline: String
    let weekRangeText: String
    let stepHitDays: Int
    let proteinHitDays: Int
    let calorieHitDays: Int
    let scorecards: [WeeklyScorecard]
    let recommendationHeadline: String
    let recommendationChips: [String]
    let wins: [String]
    let focus: [String]
    let adjustments: [WeeklyAdjustment]
    let hasEnoughData: Bool
}

struct MealQualityContext: Equatable {
    let mealType: MealType?
    let goalType: String
    let calorieTarget: Int
    let proteinTarget: Int
    let caloriesRemaining: Int?
    let proteinRemaining: Double?
    let healthConditions: [String]
}

struct MealQualityIndicator: Equatable, Identifiable {
    let id: String
    let label: String
    let status: String
}

struct MealQualityResult: Equatable {
    let rating: String
    let meter: Int
    let indicators: [MealQualityIndicator]
    let summary: String
    let tip: String
}

struct DailyDeltaContext: Equatable {
    struct Snapshot: Equatable {
        let caloriesConsumed: Int
        let proteinConsumed: Double
        let steps: Int
        let activeEnergyBurned: Int?
        let waterLitres: Double
        let readinessScore: Int?
        let readinessStatus: String?
        let hasWorkout: Bool
    }

    let goalType: String
    let calorieTarget: Int
    let proteinTarget: Int
    let stepTarget: Int
    let today: Snapshot
    let yesterday: Snapshot?
    let averageSteps: Int?
    let averageActiveEnergy: Int?
}

struct DailyDeltaGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let bullets: [String]
}

struct DailyDelta: Equatable {
    let bullets: [String]
    let tldr: String
    let homePreview: String
    let groups: [DailyDeltaGroup]
}
