import Foundation

struct AdaptivePlanInput: Equatable {
    struct GoalContext: Equatable {
        let goalType: String
        let targetWeightKg: Double?
        let timelineWeeks: Int?
    }

    struct BaseTargets: Equatable {
        let calorieTarget: Int
        let proteinTargetGrams: Int
        let stepTarget: Int
        let waterTargetLiters: Double
        let burnTargetKcal: Int?
    }

    struct Progress: Equatable {
        let caloriesConsumed: Int
        let proteinConsumedGrams: Double
        let carbsConsumedGrams: Double
        let fatConsumedGrams: Double
        let stepsCompleted: Int
        let activeEnergyBurnedKcal: Int?
        let estimatedTotalBurnKcal: Int?
        let workoutEnergyBurnedKcal: Int?
        let waterConsumedLiters: Double?
    }

    struct ReadinessContext: Equatable {
        let score: Int?
        let status: String
        let usedDefaultSleep: Bool
    }

    struct HistoricalPerformance: Equatable {
        let sevenDayAvgSteps: Int?
        let sevenDayAvgActiveEnergyKcal: Int?
        let proteinTargetHitDaysLast7: Int?
        let stepTargetHitDaysLast7: Int?
        let calorieTargetHitDaysLast7: Int?
        let readinessTrend: String?
        let strengthSessionsLast7Days: Int?
    }

    struct TodayContext: Equatable {
        let currentHour: Int?
        let mealsLoggedToday: Int
        let workoutToday: Bool
        let workoutYesterday: Bool
        let supplementsDue: [AdaptiveSupplementReminder]
        let healthConditions: [String]
    }

    let userId: String
    let date: String
    let goal: GoalContext
    let baseTargets: BaseTargets
    let progress: Progress
    let readiness: ReadinessContext
    let historicalPerformance: HistoricalPerformance
    let todayContext: TodayContext
}

struct AdaptiveSupplementReminder: Equatable, Identifiable {
    let id: String
    let supplementId: String
    let name: String
    let timing: String?
    let status: String
}

struct AdaptivePlanOutput: Codable, Equatable {
    struct CalorieAdvice: Codable, Equatable {
        let baseTarget: Int
        let recommendedAction: String
        let message: String
    }

    struct ProteinAdvice: Codable, Equatable {
        let targetGrams: Int
        let remainingGrams: Double
        let urgency: String
        let message: String
    }

    struct ActivityAdvice: Codable, Equatable {
        let stepTarget: Int
        let stepsRemaining: Int
        let cardioRecommendation: String
        let estimatedCardioBurnKcal: Int?
        let message: String
    }

    struct StrengthAdvice: Codable, Equatable {
        let recommendation: String
        let durationMinutes: Int
        let intensity: String
        let estimatedBurnKcal: Int?
        let message: String
    }

    struct MealGuidance: Codable, Equatable {
        let dietFocus: String
        let nextMealStrategy: String
        let suggestedMealTypes: [String]
    }

    struct NextBestAction: Codable, Equatable, Identifiable {
        var id: String { title + category }
        let title: String
        let description: String
        let category: String
        let priority: String
    }

    struct AdaptiveNudge: Codable, Equatable, Identifiable {
        var id: String { message + category }
        let message: String
        let reason: String
        let urgency: String
        let category: String
    }

    let planMode: String
    let calorieAdvice: CalorieAdvice
    let proteinAdvice: ProteinAdvice
    let activityAdvice: ActivityAdvice
    let strengthAdvice: StrengthAdvice
    let mealGuidance: MealGuidance
    let nextBestActions: [NextBestAction]
    let nudges: [AdaptiveNudge]
    let explanation: [String]
}

