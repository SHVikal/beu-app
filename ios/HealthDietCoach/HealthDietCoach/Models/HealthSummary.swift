import Foundation

struct HealthSummary: Codable, Identifiable {
    var id: String { "\(userId)-\(date)" }

    let userId: String
    let date: String
    let steps: Int
    let activeEnergyKcal: Double
    let basalEnergyKcal: Double?
    let workoutCount: Int
    let workoutMinutes: Double
    let workoutEnergyKcal: Double
    let totalEnergyBurnedKcal: Double?
    let estimatedTotalBurnKcal: Double
    let sleepHours: Double
    let restingHeartRateBpm: Double?
    let hrvMs: Double?
    let weightKg: Double?
    let heightCm: Double?
}

enum UserGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "fat_loss"
    case muscleGain = "muscle_gain"
    case maintenance = "maintenance"
    case generalWellness = "general_wellness"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fatLoss: return "Fat Loss"
        case .muscleGain: return "Muscle Gain"
        case .maintenance: return "Maintenance"
        case .generalWellness: return "General Wellness"
        }
    }
}

struct UserGoalPayload: Codable {
    let userId: String
    let goal: UserGoal
    let notes: String?
}

struct UserGoalResponse: Codable {
    let userId: String
    let goal: UserGoal
    let notes: String?
    let createdAt: String?
    let updatedAt: String?
}

struct DietRecommendation: Codable {
    let insightTitle: String
    let summary: String
    let personalizationNote: String
    let suggestedCalorieDirection: String
    let proteinGuidance: String
    let carbGuidance: String
    let hydrationGuidance: String
    let mealSuggestions: [String]
    let recoveryNote: String
    let nextBestAction: String
    let focusAreas: [String]
    let safetyNote: String
    let signals: [String]
}

struct WeeklySummaryResponse: Codable {
    let userId: String
    let days: Int
    let summaries: [HealthSummary]
}

enum FoodAdherence: String, Codable, CaseIterable, Identifiable {
    case yes
    case partial
    case no

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .partial: return "Partial"
        case .no: return "No"
        }
    }

    var score: Double {
        switch self {
        case .yes: return 1
        case .partial: return 0.5
        case .no: return 0
        }
    }
}

struct FoodLogEntry: Codable {
    let date: String
    let adherence: FoodAdherence
    let tags: [String]
}

struct ReadinessCardModel {
    let score: Int?
    let status: String
    let message: String
    let contributingFactors: [String]
}

struct ReadinessTrendPoint: Identifiable, Codable {
    var id: String { date }

    let date: String
    let score: Int?
    let status: String
    let topReason: String
}

struct ReadinessTrendSummary {
    let points: [ReadinessTrendPoint]
    let averageScore: Int?
    let highestScore: Int?
    let lowestScore: Int?
    let trendDirection: String
    let summaryMessage: String
}

struct InsightsCardModel {
    let items: [String]
}

struct DailyPlanCardModel {
    let readinessScore: Int?
    let readinessStatus: String
    let calorieDirection: String
    let proteinTarget: String
    let carbAdjustment: String
    let hydrationLiters: Double
    let meals: [String]
    let priorityActions: [String]
    let supplementReminders: [String]
    let healthContextNotes: [String]
    let recoveryNote: String
    let safetyNote: String?
    let explanation: [String]
}

struct DailyEnergyBalance: Codable, Equatable {
    let date: String
    let calorieIntakeTarget: Int
    let caloriesConsumed: Int
    let activeEnergyBurned: Int
    let basalEnergyBurned: Int?
    let workoutEnergyBurned: Int
    let estimatedTotalBurn: Int
    let dailyBurnTarget: Int
    let remainingBurnTarget: Int
    let netCalories: Int
    let targetNetCalories: Int?
    let energyBalanceStatus: String
    let message: String
}

struct WeeklyEnergySummary: Codable, Equatable {
    let avgCaloriesConsumed: Int
    let avgCalorieIntakeTarget: Int
    let avgEstimatedBurn: Int
    let avgBurnTarget: Int
    let totalWorkoutEnergyBurned: Int
    let daysBurnTargetMet: Int
    let daysIntakeTargetMet: Int
    let energyTrend: String
    let message: String
}

struct ConsistencyCardModel {
    let currentStreak: Int
    let weeklyConsistencyScore: Int
    let message: String
}

enum SupplementFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case asNeeded = "as_needed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .asNeeded: return "As needed"
        }
    }
}

enum SupplementTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case withMeal = "with_meal"
    case beforeBed = "before_bed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .withMeal: return "With meal"
        case .beforeBed: return "Before bed"
        }
    }

    var reminderPhrase: String {
        switch self {
        case .morning: return "in the morning"
        case .afternoon: return "in the afternoon"
        case .evening: return "in the evening"
        case .withMeal: return "with a meal"
        case .beforeBed: return "before bed"
        }
    }
}

enum ConditionType: String, Codable, CaseIterable, Identifiable {
    case pcos
    case diabetes
    case thyroid
    case hypertension
    case anemia
    case cholesterol
    case pregnancy
    case eatingDisorderHistory = "eating_disorder_history"
    case other
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pcos: return "PCOS"
        case .diabetes: return "Diabetes"
        case .thyroid: return "Thyroid"
        case .hypertension: return "Hypertension"
        case .anemia: return "Anemia"
        case .cholesterol: return "Cholesterol"
        case .pregnancy: return "Pregnancy"
        case .eatingDisorderHistory: return "Eating disorder history"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

struct Supplement: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    var name: String
    var dosage: String?
    var frequency: SupplementFrequency
    var timeOfDay: SupplementTime?
    var notes: String?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
}

struct HealthCondition: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    var conditionType: ConditionType
    var customName: String?
    var notes: String?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
}

enum NutritionProfileSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum NutritionGoalType: String, Codable, CaseIterable, Identifiable {
    case loseWeight = "lose_weight"
    case maintainWeight = "maintain_weight"
    case gainMuscle = "gain_muscle"
    case generalWellness = "general_wellness"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: return "Lose weight"
        case .maintainWeight: return "Maintain weight"
        case .gainMuscle: return "Gain muscle"
        case .generalWellness: return "General wellness"
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }
}

struct UserNutritionProfile: Codable, Identifiable {
    var id: String { userId }

    let userId: String
    let age: Int?
    let sex: NutritionProfileSex?
    let heightCm: Double
    let currentWeightKg: Double
    let targetWeightKg: Double?
    let goalType: NutritionGoalType
    let dailyCalorieTarget: Int
    let dailyProteinTargetGrams: Int
    let dailyCarbTargetGrams: Int?
    let dailyFatTargetGrams: Int?
    let targetTimeline: String?
    let createdAt: String
    let updatedAt: String
}

struct DetectedFoodItem: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var estimatedPortion: String
    var quantityGrams: Double?
    var confidence: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var userConfirmed: Bool
}

struct FoodImageAnalysis: Codable, Identifiable {
    let id: String
    let userId: String
    let inputType: String
    let originalDescription: String?
    let imageLocalPath: String?
    let imageRemoteUrl: String?
    var detectedItems: [DetectedFoodItem]
    var totalCalories: Int
    var totalProteinGrams: Double
    var totalCarbsGrams: Double
    var totalFatGrams: Double
    let confidence: String
    let notes: [String]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case analysisId
        case userId
        case inputType
        case originalDescription
        case imageLocalPath
        case imageRemoteUrl
        case detectedItems
        case totalCalories
        case totalProteinGrams
        case totalCarbsGrams
        case totalFatGrams
        case confidence
        case notes
        case createdAt
    }

    init(
        id: String,
        userId: String,
        inputType: String = "image",
        originalDescription: String? = nil,
        imageLocalPath: String?,
        imageRemoteUrl: String?,
        detectedItems: [DetectedFoodItem],
        totalCalories: Int,
        totalProteinGrams: Double,
        totalCarbsGrams: Double,
        totalFatGrams: Double,
        confidence: String,
        notes: [String],
        createdAt: String
    ) {
        self.id = id
        self.userId = userId
        self.inputType = inputType
        self.originalDescription = originalDescription
        self.imageLocalPath = imageLocalPath
        self.imageRemoteUrl = imageRemoteUrl
        self.detectedItems = detectedItems
        self.totalCalories = totalCalories
        self.totalProteinGrams = totalProteinGrams
        self.totalCarbsGrams = totalCarbsGrams
        self.totalFatGrams = totalFatGrams
        self.confidence = confidence
        self.notes = notes
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .analysisId)
            ?? container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        inputType = try container.decodeIfPresent(String.self, forKey: .inputType) ?? "image"
        originalDescription = try container.decodeIfPresent(String.self, forKey: .originalDescription)
        imageLocalPath = try container.decodeIfPresent(String.self, forKey: .imageLocalPath)
        imageRemoteUrl = try container.decodeIfPresent(String.self, forKey: .imageRemoteUrl)
        detectedItems = try container.decode([DetectedFoodItem].self, forKey: .detectedItems)
        totalCalories = try container.decode(Int.self, forKey: .totalCalories)
        totalProteinGrams = try container.decode(Double.self, forKey: .totalProteinGrams)
        totalCarbsGrams = try container.decode(Double.self, forKey: .totalCarbsGrams)
        totalFatGrams = try container.decode(Double.self, forKey: .totalFatGrams)
        confidence = try container.decode(String.self, forKey: .confidence)
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(inputType, forKey: .inputType)
        try container.encodeIfPresent(originalDescription, forKey: .originalDescription)
        try container.encodeIfPresent(imageLocalPath, forKey: .imageLocalPath)
        try container.encodeIfPresent(imageRemoteUrl, forKey: .imageRemoteUrl)
        try container.encode(detectedItems, forKey: .detectedItems)
        try container.encode(totalCalories, forKey: .totalCalories)
        try container.encode(totalProteinGrams, forKey: .totalProteinGrams)
        try container.encode(totalCarbsGrams, forKey: .totalCarbsGrams)
        try container.encode(totalFatGrams, forKey: .totalFatGrams)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct MealLog: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let date: String
    let dayOfWeek: String
    let mealType: MealType
    let loggedAt: String
    let source: String
    let originalInput: String?
    let imageLocalPath: String?
    let items: [DetectedFoodItem]
    let totalCalories: Int
    let totalProteinGrams: Double
    let totalCarbsGrams: Double
    let totalFatGrams: Double
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case date
        case dayOfWeek
        case mealType
        case loggedAt
        case source
        case originalInput
        case imageLocalPath
        case items
        case totalCalories
        case totalProteinGrams
        case totalCarbsGrams
        case totalFatGrams
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        userId: String,
        date: String,
        dayOfWeek: String,
        mealType: MealType,
        loggedAt: String,
        source: String,
        originalInput: String?,
        imageLocalPath: String?,
        items: [DetectedFoodItem],
        totalCalories: Int,
        totalProteinGrams: Double,
        totalCarbsGrams: Double,
        totalFatGrams: Double,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.dayOfWeek = dayOfWeek
        self.mealType = mealType
        self.loggedAt = loggedAt
        self.source = source
        self.originalInput = originalInput
        self.imageLocalPath = imageLocalPath
        self.items = items
        self.totalCalories = totalCalories
        self.totalProteinGrams = totalProteinGrams
        self.totalCarbsGrams = totalCarbsGrams
        self.totalFatGrams = totalFatGrams
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        date = try container.decode(String.self, forKey: .date)
        dayOfWeek = try container.decodeIfPresent(String.self, forKey: .dayOfWeek) ?? MealLog.dayOfWeekString(from: date)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        let created = try container.decode(String.self, forKey: .createdAt)
        loggedAt = try container.decodeIfPresent(String.self, forKey: .loggedAt) ?? created
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        originalInput = try container.decodeIfPresent(String.self, forKey: .originalInput)
        imageLocalPath = try container.decodeIfPresent(String.self, forKey: .imageLocalPath)
        items = try container.decode([DetectedFoodItem].self, forKey: .items)
        totalCalories = try container.decode(Int.self, forKey: .totalCalories)
        totalProteinGrams = try container.decode(Double.self, forKey: .totalProteinGrams)
        totalCarbsGrams = try container.decode(Double.self, forKey: .totalCarbsGrams)
        totalFatGrams = try container.decode(Double.self, forKey: .totalFatGrams)
        createdAt = created
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    static func dayOfWeekString(from isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return "Unknown" }
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

struct DietSuggestionHistory: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let date: String
    let dayOfWeek: String
    let mealType: String
    let suggestedMealName: String
    let estimatedCalories: Int
    let estimatedProteinGrams: Int
    let reason: String
    let shownAt: String
}

struct DailyNutritionProgress: Codable {
    let userId: String
    let date: String
    let calorieTarget: Int
    let proteinTargetGrams: Int
    let consumedCalories: Int
    let consumedProteinGrams: Double
    let consumedCarbsGrams: Double
    let consumedFatGrams: Double
    let remainingCalories: Int
    let remainingProteinGrams: Double
}

struct WeeklyNutritionSummaryDay: Codable, Identifiable {
    var id: String { date }

    let date: String
    let consumedCalories: Int
    let consumedProteinGrams: Double
    let mealCount: Int
}

struct WeeklyNutritionSummary: Codable {
    let userId: String
    let startDate: String
    let endDate: String
    let calorieTarget: Int
    let proteinTargetGrams: Int
    let averageCalories: Int
    let averageProteinGrams: Double
    let loggedDays: Int
    let totalMeals: Int
    let summaryLines: [String]
    let dailyBreakdown: [WeeklyNutritionSummaryDay]
}
