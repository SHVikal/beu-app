import Foundation

enum EnginePlanPriority: String, Codable {
    case high
    case medium
    case low
}

enum EnginePlanCategory: String, Codable {
    case nutrition
    case hydration
    case activity
    case recovery
    case supplement
}

enum EngineNudgeUrgency: String, Codable {
    case low
    case medium
    case high
}

enum EngineNudgeTone: String, Codable {
    case soft
    case alert
    case win
}

enum EngineStrengthRecommendation: String, Codable {
    case required
    case optional
    case rest
}

enum EngineStrengthIntensity: String, Codable {
    case light
    case moderate
    case high
}

struct EngineStrengthTrainingPlan: Codable {
    let recommendation: EngineStrengthRecommendation
    let durationMinutes: Int
    let intensity: EngineStrengthIntensity
    let focus: String?
}

struct DailyPersonalizedActionPlanTargets: Codable {
    let calories: Int
    let proteinGrams: Int
    let waterLiters: Double
    let steps: Int
    let cardioMinutes: Int
    let strengthTraining: EngineStrengthTrainingPlan
}

struct DailyPersonalizedActionPlanProgress: Codable {
    let caloriesConsumed: Int
    let caloriesRemaining: Int
    let proteinConsumedGrams: Double
    let proteinRemainingGrams: Double
    let stepsCompleted: Int
    let stepsRemaining: Int
    let waterConsumedLiters: Double
    let waterRemainingLiters: Double
}

struct DailyPersonalizedPriorityAction: Codable, Identifiable {
    var id: String { "\(category.rawValue)-\(title)" }

    let title: String
    let description: String
    let priority: EnginePlanPriority
    let category: EnginePlanCategory
}

struct DailyPersonalizedNudge: Codable, Identifiable {
    let id: String
    let message: String
    let reason: String
    let category: EnginePlanCategory
    let urgency: EngineNudgeUrgency
    let tone: EngineNudgeTone
    let action: String?
}

struct DailyPersonalizedActionPlan: Codable {
    let userId: String
    let date: String
    let onboardingRequired: Bool?
    let targets: DailyPersonalizedActionPlanTargets
    let progress: DailyPersonalizedActionPlanProgress
    let planSummary: String
    let priorityActions: [DailyPersonalizedPriorityAction]
    let realTimeNudges: [DailyPersonalizedNudge]
    let supplementReminders: [String]
    let healthContextNotes: [String]
    let explanation: [String]
    let safetyNote: String
    let carbGuidance: String
    let calorieDirection: String
    let proteinLevel: String
}

struct WeeklyPersonalizedActionPlanTargets: Codable {
    let avgDailyCalories: Int
    let avgDailyProteinGrams: Int
    let totalStrengthSessions: Int
    let totalCardioMinutes: Int
    let avgDailySteps: Int
    let avgDailyWaterLiters: Double
}

struct WeeklyPersonalizedActionPlanFeedback: Codable {
    let readinessTrend: String
    let calorieConsistency: String
    let proteinConsistency: String
    let activityConsistency: String
    let recoveryConsistency: String
}

struct WeeklyRecommendedAdjustment: Codable, Identifiable {
    var id: String { title }

    let title: String
    let description: String
    let reason: String
}

struct WeeklyPersonalizedActionPlan: Codable {
    let userId: String
    let weekStartDate: String
    let weekEndDate: String
    let onboardingRequired: Bool?
    let weeklyTargets: WeeklyPersonalizedActionPlanTargets
    let weeklyFocus: [String]
    let weeklyFeedback: WeeklyPersonalizedActionPlanFeedback
    let recommendedAdjustments: [WeeklyRecommendedAdjustment]
    let explanation: [String]
    let safetyNote: String
}

struct WeeklyInsightCard: Codable, Identifiable {
    var id: String { kicker + sentence }

    let kicker: String
    let sentence: String
}

struct WeeklyInsightAction: Codable, Identifiable {
    var id: String { title }

    let title: String
    let description: String
}

struct WeeklyInsightsResponse: Codable {
    let userId: String
    let weekStartDate: String
    let weekEndDate: String
    let averageReadiness: Int?
    let consistencyScore: Int
    let trendDirection: String
    let cards: [WeeklyInsightCard]
    let actions: [WeeklyInsightAction]
    let disclaimer: String
}

struct WaterLogEntry: Codable {
    let id: String
    let userId: String
    let date: String
    let litres: Double
    let createdAt: String?
}

struct LogWaterResponse: Codable {
    let waterLog: WaterLogEntry
    let plan: DailyPersonalizedActionPlan
}

struct PlanMealLogRequest: Codable {
    let userId: String
    let source: String
    let text: String?
    let image: String?
    let mealSlot: MealType
    let items: [DetectedFoodItem]
    let date: String?
}

struct DailyPlanMealLogResponse: Codable {
    let mealLog: MealLog
    let progress: DailyPersonalizedActionPlanProgress
    let nudges: [DailyPersonalizedNudge]
}
