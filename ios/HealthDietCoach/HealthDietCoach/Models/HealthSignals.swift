import Foundation

struct DailyIntake: Codable, Equatable {
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var waterLitres: Double
    var steps: Int
    var mealsLoggedToday: Int
    var lastMealType: MealType?
}

struct HealthSignals: Codable, Equatable {
    var sleepHours: Double
    var sleepTarget: Double
    var hrv: Int
    var rhr: Int
}
