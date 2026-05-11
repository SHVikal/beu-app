import Foundation

enum PlanStrengthKind: String, Codable {
    case required
    case optional
    case rest
}

struct PlanStrengthRecommendation: Codable, Equatable {
    var kind: PlanStrengthKind
    var durationMinutes: Int
    var intensity: String
}

struct DailyPlan: Codable, Equatable {
    var kcalTarget: Int
    var proteinTarget: Int
    var waterLitresTarget: Double
    var baseTargets: BaseTargets
    var dynamicTargets: DynamicTargetResult
    var carbGuidance: String
    var calorieDirection: String
    var proteinLevel: String
    var strength: PlanStrengthRecommendation
    var cardioStepsTarget: Int
    var cardioMessage: String
    var energyBalance: DailyEnergyBalance
    var adaptivePlan: AdaptivePlanOutput
    var dietGuidance: DietGuidance
    var supplementReminders: [String]
    var healthContextNote: String?
    var safetyNote: String?
    var explanation: [String]
}

struct DietGuidance: Codable, Equatable {
    var date: String
    var dayOfWeek: String
    var dietPriority: String
    var targetContext: String
    var readinessContext: String
    var metadataContext: String
    var healthContext: String
    var nextMealStrategy: String
    var mealSuggestionsByType: MealSuggestionsByType
    var foodGroupsToPrioritize: [String]
    var foodGroupsToLimit: [String]
    var supplementContextNotes: [String]
    var safetyNote: String
}

struct MealSuggestionsByType: Codable, Equatable {
    var breakfast: [MealSuggestion]
    var lunch: [MealSuggestion]
    var dinner: [MealSuggestion]
    var snacks: [MealSuggestion]
}

struct MealSuggestion: Codable, Equatable, Identifiable {
    var id: String { "\(mealType)-\(name)" }

    var name: String
    var mealType: String
    var description: String
    var estimatedCalories: Int
    var estimatedProteinGrams: Int
    var estimatedCarbsGrams: Int?
    var estimatedFatGrams: Int?
    var whyItFits: String
    var personalizationReason: String
    var conditionFitNote: String?
    var readinessFitNote: String?
    var targetFitNote: String?
}

enum NudgeTone: String, Codable {
    case soft
    case alert
    case win
}

struct DailyNudge: Codable, Identifiable, Equatable {
    let id: String
    let tone: NudgeTone
    let message: String
    let action: String?
}

struct WeeklyInsightCardModel: Codable, Identifiable, Equatable {
    var id: String { kicker + sentence }
    let kicker: String
    let sentence: String
}

struct WeeklyInsightActionModel: Codable, Identifiable, Equatable {
    var id: String { number + title }
    let number: String
    let title: String
    let subtitle: String
}

struct WeeklyTargetAverage: Codable, Equatable, Identifiable {
    var id: String { label }
    let label: String
    let valueLabel: String
    let progress: Double
}

struct WeeklyInsights: Codable, Equatable {
    let averageReadiness: Int
    let consistencyScore: Int
    let trendLabel: String
    let trendDelta: String
    let weeklyEnergySummary: WeeklyEnergySummary
    let targetAverages: [WeeklyTargetAverage]
    let cards: [WeeklyInsightCardModel]
    let actions: [WeeklyInsightActionModel]
}

enum LanguageGuard {
    static let forbiddenSubstrings = [
        "diagnose",
        "prescribe",
        "dosage",
        "start taking",
        "stop taking",
        "interaction",
        "insulin",
        "treat",
    ]

    static func sanitized(_ text: String) -> String {
        var candidate = text
        for forbidden in forbiddenSubstrings {
            candidate = candidate.replacingOccurrences(of: forbidden, with: "", options: .caseInsensitive)
        }
        return candidate.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitized(_ lines: [String]) -> [String] {
        lines.map(sanitized)
    }
}
