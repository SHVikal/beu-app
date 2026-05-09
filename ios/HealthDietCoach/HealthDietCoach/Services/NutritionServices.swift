import Foundation
import UIKit

enum BeUSafetyCopy {
    static let wellnessDisclaimer = "BeU provides general wellness guidance only and does not replace medical advice."
}

struct NutritionFoodReference {
    let name: String
    let defaultServingGrams: Double
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
}

struct NutritionMacroTotals {
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
}

struct NutritionTargetSuggestion {
    let calories: Int
    let proteinGrams: Int
    let carbsGrams: Int?
    let fatGrams: Int?
    let activityMultiplier: Double
}

protocol FoodImageAnalysisService {
    func analyzeFoodImage(_ image: UIImage, userId: String) async throws -> FoodImageAnalysis
    func analyzeFoodText(_ description: String, userId: String, mealType: MealType?, dietPreference: String) async throws -> FoodImageAnalysis
    func estimateMacros(items: [DetectedFoodItem]) -> NutritionMacroTotals
    func updateDetectedItems(_ items: [DetectedFoodItem], userId: String, imageLocalPath: String?, analysisId: String?) async throws -> FoodImageAnalysis
}

final class UserNutritionProfileService {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func profile(for userId: String) -> UserNutritionProfile? {
        guard let data = userDefaults.data(forKey: profileKey(for: userId)) else { return nil }
        return try? JSONDecoder().decode(UserNutritionProfile.self, from: data)
    }

    func save(_ profile: UserNutritionProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: profileKey(for: profile.userId))
        }
        userDefaults.set(true, forKey: onboardingKey(for: profile.userId))
    }

    func hasCompletedOnboarding(for userId: String) -> Bool {
        userDefaults.bool(forKey: onboardingKey(for: userId))
    }

    func setOnboardingCompleted(_ completed: Bool, userId: String) {
        userDefaults.set(completed, forKey: onboardingKey(for: userId))
    }

    private func profileKey(for userId: String) -> String {
        "nutritionProfile_\(userId)"
    }

    private func onboardingKey(for userId: String) -> String {
        "nutritionOnboardingCompleted_\(userId)"
    }
}

struct NutritionLookupService {
    let foods: [String: NutritionFoodReference] = [
        "chicken breast": .init(name: "Chicken breast", defaultServingGrams: 150, caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
        "rice": .init(name: "Rice", defaultServingGrams: 120, caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
        "egg": .init(name: "Egg", defaultServingGrams: 60, caloriesPer100g: 143, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 9.5),
        "oats": .init(name: "Oats", defaultServingGrams: 60, caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9),
        "banana": .init(name: "Banana", defaultServingGrams: 100, caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 22.8, fatPer100g: 0.3),
        "avocado": .init(name: "Avocado", defaultServingGrams: 80, caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 8.5, fatPer100g: 14.7),
        "salmon": .init(name: "Salmon", defaultServingGrams: 140, caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
        "salad": .init(name: "Salad", defaultServingGrams: 80, caloriesPer100g: 20, proteinPer100g: 1.2, carbsPer100g: 3.6, fatPer100g: 0.2),
        "yogurt": .init(name: "Yogurt", defaultServingGrams: 150, caloriesPer100g: 63, proteinPer100g: 5.3, carbsPer100g: 7, fatPer100g: 1.6),
        "bread": .init(name: "Bread", defaultServingGrams: 60, caloriesPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3.2),
        "pasta": .init(name: "Pasta", defaultServingGrams: 140, caloriesPer100g: 157, proteinPer100g: 5.8, carbsPer100g: 30.9, fatPer100g: 0.9),
        "beef": .init(name: "Beef", defaultServingGrams: 150, caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15),
        "tofu": .init(name: "Tofu", defaultServingGrams: 140, caloriesPer100g: 144, proteinPer100g: 17.3, carbsPer100g: 2.8, fatPer100g: 8.7),
        "protein shake": .init(name: "Protein shake", defaultServingGrams: 300, caloriesPer100g: 60, proteinPer100g: 10, carbsPer100g: 3, fatPer100g: 1.5),
        "coffee": .init(name: "Coffee", defaultServingGrams: 240, caloriesPer100g: 1, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0),
        "milk": .init(name: "Milk", defaultServingGrams: 240, caloriesPer100g: 50, proteinPer100g: 3.4, carbsPer100g: 5, fatPer100g: 1.9)
    ]

    func reference(for foodName: String) -> NutritionFoodReference? {
        let normalized = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = foods[normalized] {
            return exact
        }
        return foods.first(where: { normalized.contains($0.key) })?.value
    }

    func buildItem(name: String, portion: String? = nil, grams: Double? = nil, confidence: String = "medium", userConfirmed: Bool = false) -> DetectedFoodItem {
        let reference = reference(for: name)
        let servingGrams = grams ?? reference?.defaultServingGrams
        let portionText = portion ?? defaultPortionText(for: reference, grams: servingGrams)
        let totals = estimateTotals(for: reference, grams: servingGrams)

        return DetectedFoodItem(
            id: UUID().uuidString,
            name: reference?.name ?? name,
            estimatedPortion: portionText,
            quantityGrams: servingGrams,
            confidence: reference == nil ? "low" : confidence,
            calories: totals.calories,
            proteinGrams: totals.proteinGrams,
            carbsGrams: totals.carbsGrams,
            fatGrams: totals.fatGrams,
            userConfirmed: userConfirmed
        )
    }

    func recalculate(item: DetectedFoodItem) -> DetectedFoodItem {
        let reference = reference(for: item.name)
        let totals = estimateTotals(for: reference, grams: item.quantityGrams)

        return DetectedFoodItem(
            id: item.id,
            name: item.name,
            estimatedPortion: item.estimatedPortion,
            quantityGrams: item.quantityGrams ?? reference?.defaultServingGrams,
            confidence: reference == nil ? "low" : item.confidence,
            calories: totals.calories,
            proteinGrams: totals.proteinGrams,
            carbsGrams: totals.carbsGrams,
            fatGrams: totals.fatGrams,
            userConfirmed: item.userConfirmed
        )
    }

    func totals(for items: [DetectedFoodItem]) -> NutritionMacroTotals {
        NutritionMacroTotals(
            calories: items.reduce(0) { $0 + $1.calories },
            proteinGrams: items.reduce(0) { $0 + $1.proteinGrams },
            carbsGrams: items.reduce(0) { $0 + $1.carbsGrams },
            fatGrams: items.reduce(0) { $0 + $1.fatGrams }
        )
    }

    private func estimateTotals(for reference: NutritionFoodReference?, grams: Double?) -> NutritionMacroTotals {
        guard let reference else {
            return NutritionMacroTotals(calories: 120, proteinGrams: 6, carbsGrams: 12, fatGrams: 4)
        }

        let serving = grams ?? reference.defaultServingGrams
        let multiplier = serving / 100
        return NutritionMacroTotals(
            calories: Int((reference.caloriesPer100g * multiplier).rounded()),
            proteinGrams: (reference.proteinPer100g * multiplier * 10).rounded() / 10,
            carbsGrams: (reference.carbsPer100g * multiplier * 10).rounded() / 10,
            fatGrams: (reference.fatPer100g * multiplier * 10).rounded() / 10
        )
    }

    private func defaultPortionText(for reference: NutritionFoodReference?, grams: Double?) -> String {
        if let grams, grams > 0 {
            return "\(Int(grams.rounded()))g"
        }
        if let reference {
            return "\(Int(reference.defaultServingGrams.rounded()))g"
        }
        return "1 serving"
    }
}

final class MockFoodImageAnalysisService: FoodImageAnalysisService {
    private let lookupService: NutritionLookupService

    init(lookupService: NutritionLookupService = NutritionLookupService()) {
        self.lookupService = lookupService
    }

    func analyzeFoodImage(_ image: UIImage, userId: String) async throws -> FoodImageAnalysis {
        let items: [DetectedFoodItem]

        if image.size.width > image.size.height {
            items = [
                lookupService.buildItem(name: "chicken breast", portion: "150g", grams: 150, confidence: "high"),
                lookupService.buildItem(name: "rice", portion: "120g", grams: 120, confidence: "medium"),
                lookupService.buildItem(name: "salad", portion: "80g", grams: 80, confidence: "medium")
            ]
        } else if abs(image.size.width - image.size.height) < 40 {
            items = [
                lookupService.buildItem(name: "salmon", portion: "140g", grams: 140, confidence: "medium"),
                lookupService.buildItem(name: "avocado", portion: "80g", grams: 80, confidence: "medium"),
                lookupService.buildItem(name: "bread", portion: "60g", grams: 60, confidence: "low")
            ]
        } else {
            items = [
                lookupService.buildItem(name: "oats", portion: "60g", grams: 60, confidence: "high"),
                lookupService.buildItem(name: "banana", portion: "100g", grams: 100, confidence: "medium"),
                lookupService.buildItem(name: "yogurt", portion: "150g", grams: 150, confidence: "medium")
            ]
        }

        return try await updateDetectedItems(items, userId: userId, imageLocalPath: nil, analysisId: nil)
    }

    func estimateMacros(items: [DetectedFoodItem]) -> NutritionMacroTotals {
        lookupService.totals(for: items)
    }

    func analyzeFoodText(_ description: String, userId: String, mealType: MealType?, dietPreference: String) async throws -> FoodImageAnalysis {
        let normalized = description
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let items = normalized.isEmpty
            ? [lookupService.buildItem(name: description, portion: "Estimated serving", grams: 100, confidence: "low")]
            : normalized.map { phrase in
                let lowercase = phrase.lowercased()
                if let match = lookupService.foods.keys.sorted(by: { $0.count > $1.count }).first(where: { lowercase.contains($0) }) {
                    return lookupService.buildItem(name: match, portion: "Estimated serving", confidence: "medium")
                }
                return lookupService.buildItem(name: phrase, portion: "Estimated serving", grams: 100, confidence: "low")
            }

        let totals = lookupService.totals(for: items)
        return FoodImageAnalysis(
            id: UUID().uuidString,
            userId: userId,
            inputType: "text",
            originalDescription: description,
            imageLocalPath: nil,
            imageRemoteUrl: nil,
            detectedItems: items,
            totalCalories: totals.calories,
            totalProteinGrams: totals.proteinGrams,
            totalCarbsGrams: totals.carbsGrams,
            totalFatGrams: totals.fatGrams,
            confidence: items.contains(where: { $0.confidence == "low" }) ? "low" : "medium",
            notes: [
                "Nutrition values are estimates based on the described meal.",
                "Please confirm items and portions before logging."
            ],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func updateDetectedItems(_ items: [DetectedFoodItem], userId: String, imageLocalPath: String?, analysisId: String? = nil) async throws -> FoodImageAnalysis {
        let recalculatedItems = items.map(lookupService.recalculate(item:))
        let totals = estimateMacros(items: recalculatedItems)
        let confidence = recalculatedItems.contains(where: { $0.confidence == "low" }) ? "medium" : "high"

        return FoodImageAnalysis(
            id: UUID().uuidString,
            userId: userId,
            inputType: "image",
            originalDescription: nil,
            imageLocalPath: imageLocalPath,
            imageRemoteUrl: nil,
            detectedItems: recalculatedItems,
            totalCalories: totals.calories,
            totalProteinGrams: totals.proteinGrams,
            totalCarbsGrams: totals.carbsGrams,
            totalFatGrams: totals.fatGrams,
            confidence: confidence,
            notes: [
                "Nutrition values are estimates based on visible food items.",
                "Please confirm items and portions before logging."
            ],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

final class RealFoodImageAnalysisService: FoodImageAnalysisService {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func analyzeFoodImage(_ image: UIImage, userId: String) async throws -> FoodImageAnalysis {
        try await apiClient.analyzeFoodImage(userId: userId, image: image)
    }

    func analyzeFoodText(_ description: String, userId: String, mealType: MealType?, dietPreference: String) async throws -> FoodImageAnalysis {
        try await apiClient.analyzeFoodText(
            userId: userId,
            description: description,
            mealType: mealType?.rawValue ?? "unknown",
            dietPreference: dietPreference
        )
    }

    func estimateMacros(items: [DetectedFoodItem]) -> NutritionMacroTotals {
        NutritionMacroTotals(
            calories: items.reduce(0) { $0 + max(0, $1.calories) },
            proteinGrams: (items.reduce(0) { $0 + max(0, $1.proteinGrams) } * 10).rounded() / 10,
            carbsGrams: (items.reduce(0) { $0 + max(0, $1.carbsGrams) } * 10).rounded() / 10,
            fatGrams: (items.reduce(0) { $0 + max(0, $1.fatGrams) } * 10).rounded() / 10
        )
    }

    func updateDetectedItems(_ items: [DetectedFoodItem], userId: String, imageLocalPath: String?, analysisId: String?) async throws -> FoodImageAnalysis {
        let sanitizedItems = items.map { item in
            DetectedFoodItem(
                id: item.id,
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom item" : item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                estimatedPortion: item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Estimated serving" : item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines),
                quantityGrams: max(0, item.quantityGrams ?? 0),
                confidence: ["high", "medium", "low"].contains(item.confidence) ? item.confidence : "low",
                calories: max(0, item.calories),
                proteinGrams: max(0, item.proteinGrams),
                carbsGrams: max(0, item.carbsGrams),
                fatGrams: max(0, item.fatGrams),
                userConfirmed: item.userConfirmed
            )
        }
        let totals = estimateMacros(items: sanitizedItems)
        return FoodImageAnalysis(
            id: analysisId ?? UUID().uuidString,
            userId: userId,
            inputType: "image",
            originalDescription: nil,
            imageLocalPath: imageLocalPath,
            imageRemoteUrl: nil,
            detectedItems: sanitizedItems,
            totalCalories: totals.calories,
            totalProteinGrams: totals.proteinGrams,
            totalCarbsGrams: totals.carbsGrams,
            totalFatGrams: totals.fatGrams,
            confidence: sanitizedItems.contains(where: { $0.confidence == "low" }) ? "low" : sanitizedItems.contains(where: { $0.confidence == "medium" }) ? "medium" : "high",
            notes: [
                "Nutrition values are estimates based on visible food items.",
                "Please confirm items and portions before logging."
            ],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

final class MealLogService {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lookupService = NutritionLookupService()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getMealsForDate(userId: String, date: String) -> [MealLog] {
        mealLogs(for: userId, date: date)
    }

    func createMealLog(_ mealLog: MealLog) {
        saveMealLog(mealLog)
    }

    func saveMealLog(_ mealLog: MealLog) {
        var logs = mealLogs(for: mealLog.userId)
        logs.removeAll { $0.id == mealLog.id }
        logs.append(normalizedMealLog(mealLog))
        persist(logs: logs, userId: mealLog.userId)
    }

    func updateMealLog(id: String, updatedMealLog: MealLog) {
        saveMealLog(MealLog(
            id: id,
            userId: updatedMealLog.userId,
            date: updatedMealLog.date,
            dayOfWeek: updatedMealLog.dayOfWeek,
            mealType: updatedMealLog.mealType,
            loggedAt: updatedMealLog.loggedAt,
            source: updatedMealLog.source,
            originalInput: updatedMealLog.originalInput,
            imageLocalPath: updatedMealLog.imageLocalPath,
            items: updatedMealLog.items,
            totalCalories: updatedMealLog.totalCalories,
            totalProteinGrams: updatedMealLog.totalProteinGrams,
            totalCarbsGrams: updatedMealLog.totalCarbsGrams,
            totalFatGrams: updatedMealLog.totalFatGrams,
            createdAt: updatedMealLog.createdAt,
            updatedAt: updatedMealLog.updatedAt
        ))
    }

    func mealLogs(for userId: String, date: String? = nil) -> [MealLog] {
        guard let data = userDefaults.data(forKey: mealLogKey(for: userId)),
              let logs = try? decoder.decode([MealLog].self, from: data) else {
            return []
        }

        let filtered = date.map { target in
            logs.filter { $0.date == target }
        } ?? logs

        return filtered.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func deleteMealLog(id: String, userId: String) -> Bool {
        let currentLogs = mealLogs(for: userId)
        let updated = currentLogs.filter { $0.id != id }
        guard updated.count != currentLogs.count else {
            return false
        }
        persist(logs: updated, userId: userId)
        return true
    }

    func recalculateMealTotals(items: [DetectedFoodItem]) -> NutritionMacroTotals {
        lookupService.totals(for: items.map(sanitizedItem))
    }

    func recalculateDailyNutritionProgress(userId: String, date: String, profile: UserNutritionProfile) -> DailyNutritionProgress {
        DailyNutritionProgressService().progress(
            userId: userId,
            date: date,
            profile: profile,
            mealLogs: mealLogs(for: userId, date: date)
        )
    }

    func persistImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "MealLogService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not prepare image for saving."])
        }

        let folder = try imageFolderURL()
        let fileURL = folder.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    private func persist(logs: [MealLog], userId: String) {
        if let data = try? encoder.encode(logs) {
            userDefaults.set(data, forKey: mealLogKey(for: userId))
        }
    }

    private func normalizedMealLog(_ mealLog: MealLog) -> MealLog {
        let sanitizedItems = mealLog.items.map(sanitizedItem).filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let totals = recalculateMealTotals(items: sanitizedItems)

        return MealLog(
            id: mealLog.id,
            userId: mealLog.userId,
            date: mealLog.date,
            dayOfWeek: mealLog.dayOfWeek,
            mealType: mealLog.mealType,
            loggedAt: mealLog.loggedAt,
            source: mealLog.source,
            originalInput: mealLog.originalInput,
            imageLocalPath: mealLog.imageLocalPath,
            items: sanitizedItems,
            totalCalories: totals.calories,
            totalProteinGrams: totals.proteinGrams,
            totalCarbsGrams: totals.carbsGrams,
            totalFatGrams: totals.fatGrams,
            createdAt: mealLog.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func sanitizedItem(_ item: DetectedFoodItem) -> DetectedFoodItem {
        DetectedFoodItem(
            id: item.id,
            name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedPortion: item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1 serving" : item.estimatedPortion.trimmingCharacters(in: .whitespacesAndNewlines),
            quantityGrams: item.quantityGrams,
            confidence: item.confidence,
            calories: max(0, item.calories),
            proteinGrams: max(0, item.proteinGrams),
            carbsGrams: max(0, item.carbsGrams),
            fatGrams: max(0, item.fatGrams),
            userConfirmed: item.userConfirmed
        )
    }

    private func mealLogKey(for userId: String) -> String {
        "mealLogs_\(userId)"
    }

    private func imageFolderURL() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("MealImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
}

final class SupplementIntakeLogRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getLogs(userId: String, date: String) -> [SupplementIntakeLog] {
        logs(for: userId).filter { $0.date == date }
    }

    func markTaken(userId: String, supplementId: String, date: String) -> SupplementIntakeLog {
        let now = ISO8601DateFormatter().string(from: Date())
        let log = SupplementIntakeLog(
            id: SupplementIntakeLog.makeID(userId: userId, supplementId: supplementId, date: date),
            userId: userId,
            supplementId: supplementId,
            date: date,
            takenAt: now,
            status: "taken",
            createdAt: now,
            updatedAt: now
        )

        var existing = logs(for: userId)
        existing.removeAll { $0.supplementId == supplementId && $0.date == date }
        existing.append(log)
        persist(existing, userId: userId)
        return log
    }

    func undoTaken(userId: String, supplementId: String, date: String) {
        var existing = logs(for: userId)
        existing.removeAll { $0.supplementId == supplementId && $0.date == date }
        persist(existing, userId: userId)
    }

    private func logs(for userId: String) -> [SupplementIntakeLog] {
        guard let data = userDefaults.data(forKey: storageKey(for: userId)),
              let logs = try? decoder.decode([SupplementIntakeLog].self, from: data) else {
            return []
        }
        return logs.sorted { $0.takenAt < $1.takenAt }
    }

    private func persist(_ logs: [SupplementIntakeLog], userId: String) {
        if let data = try? encoder.encode(logs) {
            userDefaults.set(data, forKey: storageKey(for: userId))
        }
    }

    private func storageKey(for userId: String) -> String {
        "supplementIntakeLogs_\(userId)"
    }
}

final class DietSuggestionHistoryService {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func histories(for userId: String) -> [DietSuggestionHistory] {
        guard let data = userDefaults.data(forKey: historyKey(for: userId)),
              let histories = try? decoder.decode([DietSuggestionHistory].self, from: data) else {
            return []
        }
        return histories.sorted { $0.shownAt < $1.shownAt }
    }

    func recordSuggestions(userId: String, date: String, suggestionsByType: MealSuggestionsByType) {
        let dayOfWeek = MealLog.dayOfWeekString(from: date)
        let now = ISO8601DateFormatter().string(from: Date())
        let newEntries = [
            makeEntries(from: suggestionsByType.breakfast, userId: userId, date: date, dayOfWeek: dayOfWeek, shownAt: now),
            makeEntries(from: suggestionsByType.lunch, userId: userId, date: date, dayOfWeek: dayOfWeek, shownAt: now),
            makeEntries(from: suggestionsByType.dinner, userId: userId, date: date, dayOfWeek: dayOfWeek, shownAt: now),
            makeEntries(from: suggestionsByType.snacks, userId: userId, date: date, dayOfWeek: dayOfWeek, shownAt: now),
        ].flatMap { $0 }

        var existing = histories(for: userId)
        for entry in newEntries {
            existing.removeAll {
                $0.userId == entry.userId &&
                $0.date == entry.date &&
                $0.mealType == entry.mealType &&
                $0.suggestedMealName == entry.suggestedMealName
            }
            existing.append(entry)
        }

        if let data = try? encoder.encode(existing.suffix(120)) {
            userDefaults.set(data, forKey: historyKey(for: userId))
        }
    }

    private func historyKey(for userId: String) -> String {
        "dietSuggestionHistory_\(userId)"
    }

    private func makeEntries(from suggestions: [MealSuggestion], userId: String, date: String, dayOfWeek: String, shownAt: String) -> [DietSuggestionHistory] {
        suggestions.map {
            DietSuggestionHistory(
                id: "\(date)-\($0.mealType)-\($0.name)",
                userId: userId,
                date: date,
                dayOfWeek: dayOfWeek,
                mealType: $0.mealType,
                suggestedMealName: $0.name,
                estimatedCalories: $0.estimatedCalories,
                estimatedProteinGrams: $0.estimatedProteinGrams,
                reason: $0.personalizationReason,
                shownAt: shownAt
            )
        }
    }
}

final class DailyNutritionProgressService {
    func progress(userId: String, date: String, profile: UserNutritionProfile, mealLogs: [MealLog]) -> DailyNutritionProgress {
        let consumedCalories = mealLogs.reduce(0) { $0 + $1.totalCalories }
        let consumedProtein = mealLogs.reduce(0) { $0 + $1.totalProteinGrams }
        let consumedCarbs = mealLogs.reduce(0) { $0 + $1.totalCarbsGrams }
        let consumedFat = mealLogs.reduce(0) { $0 + $1.totalFatGrams }

        return DailyNutritionProgress(
            userId: userId,
            date: date,
            calorieTarget: profile.dailyCalorieTarget,
            proteinTargetGrams: profile.dailyProteinTargetGrams,
            consumedCalories: consumedCalories,
            consumedProteinGrams: consumedProtein,
            consumedCarbsGrams: consumedCarbs,
            consumedFatGrams: consumedFat,
            remainingCalories: profile.dailyCalorieTarget - consumedCalories,
            remainingProteinGrams: Double(profile.dailyProteinTargetGrams) - consumedProtein
        )
    }
}

struct NutritionTargetCalculator {
    static func minimumCalories(for sex: NutritionProfileSex?) -> Int {
        switch sex {
        case .female:
            return 1200
        case .male:
            return 1500
        default:
            return 1300
        }
    }

    static func estimateTargets(
        age: Int?,
        sex: NutritionProfileSex?,
        heightCm: Double,
        weightKg: Double,
        goalType: NutritionGoalType,
        activityMultiplier: Double = 1.45
    ) -> NutritionTargetSuggestion {
        let ageValue = Double(max(age ?? 30, 18))
        let sexAdjustment: Double
        switch sex {
        case .male:
            sexAdjustment = 5
        case .female:
            sexAdjustment = -161
        default:
            sexAdjustment = -78
        }

        let bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageValue) + sexAdjustment
        let estimatedTDEE = max(bmr * activityMultiplier, Double(minimumCalories(for: sex)))

        let calorieTarget: Int
        switch goalType {
        case .loseWeight:
            calorieTarget = Int((estimatedTDEE - 300).rounded())
        case .maintainWeight, .generalWellness:
            calorieTarget = Int(estimatedTDEE.rounded())
        case .gainMuscle:
            calorieTarget = Int((estimatedTDEE + 250).rounded())
        }

        let safeCalories = max(calorieTarget, minimumCalories(for: sex))
        let proteinMultiplier: Double
        switch goalType {
        case .loseWeight:
            proteinMultiplier = 1.6
        case .gainMuscle:
            proteinMultiplier = 1.8
        case .maintainWeight, .generalWellness:
            proteinMultiplier = 1.4
        }

        let proteinGrams = Int((weightKg * proteinMultiplier).rounded())
        let fatGrams = Int((Double(safeCalories) * 0.28 / 9).rounded())
        let carbCalories = Double(safeCalories) - (Double(proteinGrams) * 4) - (Double(fatGrams) * 9)
        let carbGrams = max(0, Int((carbCalories / 4).rounded()))

        return NutritionTargetSuggestion(
            calories: safeCalories,
            proteinGrams: proteinGrams,
            carbsGrams: carbGrams,
            fatGrams: fatGrams,
            activityMultiplier: activityMultiplier
        )
    }
}

struct MealConsistencyService {
    let mealLogService: MealLogService

    func summary(userId: String, referenceDate: Date = Date()) -> ConsistencyCardModel {
        let dates = lastNDates(count: 7, referenceDate: referenceDate)
        let scores = dates.map { scoreForDate($0, userId: userId) }
        let weeklyScore = Int(((scores.reduce(0, +) / 7.0) * 100).rounded())

        let streak = currentStreak(userId: userId, referenceDate: referenceDate)
        let message: String
        switch streak {
        case 0:
            message = "Start small today."
        case 1...2:
            message = "Good start. Keep it going."
        case 3...6:
            message = "You’re building momentum."
        default:
            message = "Strong consistency this week."
        }

        return ConsistencyCardModel(
            currentStreak: streak,
            weeklyConsistencyScore: weeklyScore,
            message: message
        )
    }

    private func currentStreak(userId: String, referenceDate: Date) -> Int {
        let dates = lastNDates(count: 30, referenceDate: referenceDate)
        var streak = 0

        for (index, date) in dates.enumerated() {
            let score = scoreForDate(date, userId: userId)
            if index == 0, score == 0 {
                continue
            }

            if score > 0 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    private func scoreForDate(_ date: String, userId: String) -> Double {
        let meals = mealLogService.mealLogs(for: userId, date: date)
        switch meals.count {
        case 2...:
            return 1
        case 1:
            return 0.5
        default:
            return 0
        }
    }

    private func lastNDates(count: Int, referenceDate: Date) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"

        return (0..<count).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate).map(formatter.string(from:))
        }
    }
}

@MainActor
final class SupplementService: ObservableObject {
    @Published private(set) var supplements: [Supplement] = []

    private let apiClient: APIClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetch(userId: String) async {
        loadCache(userId: userId)
        do {
            supplements = sort(try await apiClient.fetchSupplements(userId: userId))
            try persistCache(userId: userId)
        } catch {
        }
    }

    func add(_ supplement: Supplement) async throws {
        let saved = try await apiClient.createSupplement(supplement)
        supplements = sort(replacing(saved))
        try persistCache(userId: supplement.userId)
    }

    func update(_ supplement: Supplement) async throws {
        let saved = try await apiClient.updateSupplement(supplement)
        supplements = sort(replacing(saved))
        try persistCache(userId: supplement.userId)
    }

    func delete(_ supplement: Supplement) async throws {
        try await apiClient.deleteSupplement(id: supplement.id)
        supplements.removeAll { $0.id == supplement.id }
        try persistCache(userId: supplement.userId)
    }

    func toggleActive(_ supplement: Supplement) async throws {
        var updated = supplement
        updated.isActive.toggle()
        updated.updatedAt = Date()
        try await update(updated)
    }

    private func replacing(_ supplement: Supplement) -> [Supplement] {
        var next = supplements
        next.removeAll { $0.id == supplement.id }
        next.append(supplement)
        return next
    }

    private func sort(_ items: [Supplement]) -> [Supplement] {
        items.sorted {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func persistCache(userId: String) throws {
        let url = try cacheURL(fileName: "supplements_\(userId).json")
        let data = try encoder.encode(supplements)
        try data.write(to: url, options: .atomic)
    }

    private func loadCache(userId: String) {
        do {
            let url = try cacheURL(fileName: "supplements_\(userId).json")
            let data = try Data(contentsOf: url)
            supplements = sort(try decoder.decode([Supplement].self, from: data))
        } catch {
        }
    }
}

@MainActor
final class HealthHistoryService: ObservableObject {
    @Published private(set) var conditions: [HealthCondition] = []

    private let apiClient: APIClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetch(userId: String) async {
        loadCache(userId: userId)
        do {
            conditions = sort(try await apiClient.fetchHealthConditions(userId: userId))
            try persistCache(userId: userId)
        } catch {
        }
    }

    func add(_ condition: HealthCondition) async throws {
        let saved = try await apiClient.createHealthCondition(condition)
        conditions = sort(replacing(saved))
        try persistCache(userId: condition.userId)
    }

    func update(_ condition: HealthCondition) async throws {
        let saved = try await apiClient.updateHealthCondition(condition)
        conditions = sort(replacing(saved))
        try persistCache(userId: condition.userId)
    }

    func delete(_ condition: HealthCondition) async throws {
        try await apiClient.deleteHealthCondition(id: condition.id)
        conditions.removeAll { $0.id == condition.id }
        try persistCache(userId: condition.userId)
    }

    func toggleActive(_ condition: HealthCondition) async throws {
        var updated = condition
        updated.isActive.toggle()
        updated.updatedAt = Date()
        try await update(updated)
    }

    private func replacing(_ condition: HealthCondition) -> [HealthCondition] {
        var next = conditions
        next.removeAll { $0.id == condition.id }
        next.append(condition)
        return next
    }

    private func sort(_ items: [HealthCondition]) -> [HealthCondition] {
        items.sorted {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            return $0.conditionType.title.localizedCaseInsensitiveCompare($1.conditionType.title) == .orderedAscending
        }
    }

    private func persistCache(userId: String) throws {
        let url = try cacheURL(fileName: "health_conditions_\(userId).json")
        let data = try encoder.encode(conditions)
        try data.write(to: url, options: .atomic)
    }

    private func loadCache(userId: String) {
        do {
            let url = try cacheURL(fileName: "health_conditions_\(userId).json")
            let data = try Data(contentsOf: url)
            conditions = sort(try decoder.decode([HealthCondition].self, from: data))
        } catch {
        }
    }
}

struct DailyActionPlanService {
    func buildPlan(
        profile: UserNutritionProfile?,
        health: HealthSummary?,
        readiness: ReadinessCardModel,
        nutrition: DailyNutritionProgress?,
        supplements: [Supplement],
        conditions: [HealthCondition]
    ) -> DailyPlanCardModel {
        let activeConditions = conditions.filter(\.isActive)
        let activeSupplements = supplements.filter(\.isActive)
        let now = Date()

        let health = health ?? HealthSummary(
            userId: profile?.userId ?? "demo-user",
            date: isoDay(now),
            steps: 0,
            activeEnergyKcal: 0,
            basalEnergyKcal: nil,
            workoutCount: 0,
            workoutMinutes: 0,
            workoutEnergyKcal: 0,
            totalEnergyBurnedKcal: nil,
            estimatedTotalBurnKcal: 0,
            sleepHours: 0,
            restingHeartRateBpm: nil,
            hrvMs: nil,
            weightKg: profile?.currentWeightKg,
            heightCm: profile?.heightCm
        )

        let goal = profile?.goalType ?? .generalWellness
        var calorieDirection = baseCalorieDirection(goal: goal, readiness: readiness, sleepHours: health.sleepHours)
        var proteinTarget = (health.workoutCount > 0 || health.workoutMinutes > 0) ? "High" : "Moderate"
        var carbAdjustment = health.activeEnergyKcal > 400 ? "Increase" : (health.activeEnergyKcal > 0 ? "Neutral" : "Decrease")
        let hydrationLiters = max(2.0, min(3.6, (nutrition?.consumedCalories ?? 0) > 1800 ? 2.8 : 2.3))
        var meals = [
            "Build one meal around protein, color, and a steady carb.",
            "Keep a simple, repeatable meal option ready for your busiest part of the day.",
            "Use vegetables or fruit to add volume before reaching for extras."
        ]
        var priorityActions = [
            "Anchor the day with one balanced meal.",
            "Keep fluids steady across the day.",
            "Add a short walk or stretch break between tasks."
        ]
        let recoveryNote = readiness.status.lowercased() == "low"
            ? "Keep effort lighter today and protect sleep tonight."
            : "Stay consistent with meals, fluids, and a manageable activity rhythm."
        var explanation = [
            "This plan reflects your recent activity, recovery, and nutrition targets.",
            "The goal is practical, repeatable wellness guidance for today."
        ]
        let supplementReminders = buildSupplementReminders(activeSupplements, now: now)
        var healthContextNotes: [String] = []
        var safetyNote: String?

        if goal == .gainMuscle {
            calorieDirection = "Increase"
            proteinTarget = "High"
            meals[0] = "Use protein-forward meals and steady carbs to support recovery."
        }

        if readiness.status.lowercased() == "low" {
            calorieDirection = calorieDirection == "Decrease" ? "Maintain" : calorieDirection
            carbAdjustment = "Neutral"
            priorityActions = [
                "Keep meals balanced and predictable.",
                "Prioritize fluids and easier movement.",
                "Create extra space for recovery tonight."
            ]
        }

        if activeConditions.contains(where: { $0.conditionType == .pcos }) {
            priorityActions = [
                "Keep meals balanced with protein and fiber.",
                "Aim for steady eating windows today.",
                "Choose consistency over extremes."
            ]
            healthContextNotes.append("Because PCOS is in your health history, today's plan prioritizes balanced meals, protein, fiber, and consistency.")
        }

        if activeConditions.contains(where: { $0.conditionType == .diabetes }) {
            carbAdjustment = "Neutral"
            meals = meals.map { $0.replacingOccurrences(of: "steady carb", with: "balanced meals") }
            safetyNote = "For diabetes-specific nutrition guidance, please follow your clinician's advice."
            healthContextNotes.append("Today's plan keeps the language general and focused on balanced meals and consistency.")
        }

        if activeConditions.contains(where: { $0.conditionType == .pregnancy }) {
            calorieDirection = "Maintain"
            priorityActions = priorityActions.filter { !containsRestrictedLanguage($0, restricted: ["deficit", "loss", "lose"]) }
            safetyNote = "Pregnancy-specific nutrition needs should be discussed with a qualified healthcare professional."
            healthContextNotes.append("Pregnancy is in your health history, so today's plan avoids deficit language and keeps guidance general.")
        }

        if activeConditions.contains(where: { $0.conditionType == .eatingDisorderHistory }) {
            calorieDirection = "Maintain"
            priorityActions = priorityActions.filter { !containsRestrictedLanguage($0, restricted: ["deficit", "loss", "lose", "weight loss"]) }
            meals = meals.map { $0.replacingOccurrences(of: "volume", with: "satisfaction") }
            safetyNote = "If food tracking feels stressful, consider using BeU without calorie targets."
            healthContextNotes.append("Because eating disorder history is in your profile, today's plan removes deficit and weight-loss language.")
        }

        if activeConditions.contains(where: { $0.conditionType == .anemia }) {
            healthContextNotes.append("Prioritize balanced meals and follow clinician advice for iron-related needs.")
        }

        if activeConditions.contains(where: { [.hypertension, .cholesterol, .thyroid].contains($0.conditionType) }) {
            healthContextNotes.append("For condition-specific medical nutrition, please consult your healthcare provider.")
        }

        let sanitizedReminders = supplementReminders.filter { !containsForbiddenMedicalLanguage($0) }
        let sanitizedContextNotes = healthContextNotes.filter { !containsForbiddenMedicalLanguage($0) }
        let sanitizedSafetyNote = safetyNote.flatMap { containsForbiddenMedicalLanguage($0) ? nil : $0 }

        explanation.append(contentsOf: sanitizedContextNotes.prefix(1))

        return DailyPlanCardModel(
            readinessScore: readiness.score,
            readinessStatus: readiness.status,
            calorieDirection: calorieDirection,
            proteinTarget: proteinTarget,
            carbAdjustment: carbAdjustment,
            hydrationLiters: hydrationLiters,
            meals: meals,
            priorityActions: priorityActions,
            supplementReminders: Array(sanitizedReminders.prefix(3)),
            healthContextNotes: Array(sanitizedContextNotes.prefix(3)),
            recoveryNote: recoveryNote,
            safetyNote: sanitizedSafetyNote,
            explanation: explanation
        )
    }

    private func baseCalorieDirection(goal: NutritionGoalType, readiness: ReadinessCardModel, sleepHours: Double) -> String {
        switch goal {
        case .loseWeight:
            if readiness.status.lowercased() == "low" || (sleepHours > 0 && sleepHours < 6.5) {
                return "Maintain"
            }
            return "Decrease"
        case .maintainWeight, .generalWellness:
            return "Maintain"
        case .gainMuscle:
            return "Increase"
        }
    }

    private func buildSupplementReminders(_ supplements: [Supplement], now: Date) -> [String] {
        let currentBand = currentTimeBand(now)
        return supplements
            .filter { $0.frequency == .daily || $0.frequency == .weekly }
            .filter { supplement in
                guard let time = supplement.timeOfDay else { return true }
                return time == .withMeal || time == currentBand
            }
            .prefix(3)
            .map { supplement in
                if let time = supplement.timeOfDay {
                    return "You usually take \(supplement.name) \(time.reminderPhrase)."
                }
                return "You usually take \(supplement.name) around this time."
            }
    }

    private func currentTimeBand(_ date: Date) -> SupplementTime {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .beforeBed
        }
    }

    private func containsRestrictedLanguage(_ value: String, restricted: [String]) -> Bool {
        let lowered = value.lowercased()
        return restricted.contains(where: lowered.contains)
    }

    private func containsForbiddenMedicalLanguage(_ value: String) -> Bool {
        let forbidden = [
            "diagnose", "treat", "prescribe", "dosage", "start taking",
            "stop taking", "interaction", "insulin", "medication", "drug"
        ]
        let lowered = value.lowercased()
        return forbidden.contains(where: lowered.contains)
    }

    private func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private func cacheURL(fileName: String) throws -> URL {
    let fileManager = FileManager.default
    let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let folder = appSupport.appendingPathComponent("BeU", isDirectory: true)
    if !fileManager.fileExists(atPath: folder.path) {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    return folder.appendingPathComponent(fileName)
}
