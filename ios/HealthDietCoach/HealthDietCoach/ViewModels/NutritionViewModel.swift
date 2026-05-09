import Foundation
import SwiftUI
import UIKit

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var profile: UserNutritionProfile?
    @Published var dailyProgress: DailyNutritionProgress?
    @Published var todaysMeals: [MealLog] = []
    @Published var mealHistory: [MealLog] = []
    @Published var weeklySummary: WeeklyNutritionSummary?
    @Published var consistencyCard = ConsistencyCardModel(currentStreak: 0, weeklyConsistencyScore: 0, message: "Start small today.")
    @Published var showOnboarding = false
    @Published var showMealLogging = false
    @Published var showSettings = false
    @Published var showMealHistory = false
    @Published var showProfileGateway = false
    @Published var showSupplements = false
    @Published var showHealthHistory = false
    @Published var nutritionErrorMessage: String?

    let userId: String

    private let profileService: UserNutritionProfileService
    private let mealLogService: MealLogService
    private let progressService: DailyNutritionProgressService
    private let consistencyService: MealConsistencyService
    private let apiClient: APIClient
    let supplementService: SupplementService
    let healthHistoryService: HealthHistoryService

    init(
        userId: String = "demo-user",
        profileService: UserNutritionProfileService = UserNutritionProfileService(),
        mealLogService: MealLogService = MealLogService(),
        progressService: DailyNutritionProgressService = DailyNutritionProgressService(),
        apiClient: APIClient = APIClient(),
        supplementService: SupplementService? = nil,
        healthHistoryService: HealthHistoryService? = nil
    ) {
        self.userId = userId
        self.profileService = profileService
        self.mealLogService = mealLogService
        self.progressService = progressService
        self.consistencyService = MealConsistencyService(mealLogService: mealLogService)
        self.apiClient = apiClient
        self.supplementService = supplementService ?? SupplementService()
        self.healthHistoryService = healthHistoryService ?? HealthHistoryService()
        loadState()
    }

    var caloriesSummaryText: String {
        guard let progress = dailyProgress else {
            return "Set up your targets to start tracking."
        }

        if progress.remainingCalories >= 0 {
            return "\(progress.consumedCalories) / \(progress.calorieTarget) consumed, \(progress.remainingCalories) remaining"
        }

        return "\(progress.consumedCalories) / \(progress.calorieTarget) consumed, over by \(abs(progress.remainingCalories))"
    }

    var proteinSummaryText: String {
        guard let progress = dailyProgress else {
            return "Protein target appears after onboarding."
        }

        let consumed = Int(progress.consumedProteinGrams.rounded())
        let remaining = Int(progress.remainingProteinGrams.rounded())
        if remaining >= 0 {
            return "\(consumed)g / \(progress.proteinTargetGrams)g consumed, \(remaining)g remaining"
        }

        return "\(consumed)g / \(progress.proteinTargetGrams)g consumed, exceeded by \(abs(remaining))g"
    }

    func loadState() {
        profile = profileService.profile(for: userId)
        showOnboarding = !profileService.hasCompletedOnboarding(for: userId) || profile == nil
        refreshDailyProgress()
        Task {
            await syncFromBackendIfPossible()
            await supplementService.fetch(userId: userId)
            await healthHistoryService.fetch(userId: userId)
        }
    }

    func completeOnboarding(profile: UserNutritionProfile) {
        profileService.save(profile)
        self.profile = profile
        showOnboarding = false
        nutritionErrorMessage = nil
        refreshDailyProgress()
        Task {
            do {
                _ = try await apiClient.saveNutritionProfile(profile)
                await syncProgressFromBackend()
            } catch {
                await MainActor.run {
                    self.nutritionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateProfile(_ profile: UserNutritionProfile) {
        profileService.save(profile)
        self.profile = profile
        nutritionErrorMessage = nil
        refreshDailyProgress()
        Task {
            do {
                _ = try await apiClient.updateNutritionProfile(profile)
                await syncProgressFromBackend()
            } catch {
                await MainActor.run {
                    self.nutritionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func refreshDailyProgress() {
        guard let profile else {
            dailyProgress = nil
            todaysMeals = []
            mealHistory = []
            weeklySummary = nil
            consistencyCard = consistencyService.summary(userId: userId)
            return
        }

        let date = todayDateString()
        let meals = mealLogService.mealLogs(for: userId, date: date)
        mealHistory = mealLogService.mealLogs(for: userId)
        todaysMeals = meals
        dailyProgress = progressService.progress(userId: userId, date: date, profile: profile, mealLogs: meals)
        consistencyCard = consistencyService.summary(userId: userId)
    }

    func saveMealLog(image: UIImage, analysis: FoodImageAnalysis, mealType: MealType) {
        do {
            let imagePath = try mealLogService.persistImage(image)
            let now = ISO8601DateFormatter().string(from: Date())
            let meal = MealLog(
                id: UUID().uuidString,
                userId: userId,
                date: todayDateString(),
                dayOfWeek: MealLog.dayOfWeekString(from: todayDateString()),
                mealType: mealType,
                loggedAt: now,
                source: "photo",
                originalInput: nil,
                imageLocalPath: imagePath,
                items: analysis.detectedItems,
                totalCalories: analysis.totalCalories,
                totalProteinGrams: analysis.totalProteinGrams,
                totalCarbsGrams: analysis.totalCarbsGrams,
                totalFatGrams: analysis.totalFatGrams,
                createdAt: now,
                updatedAt: now
            )
            mealLogService.saveMealLog(meal)
            nutritionErrorMessage = nil
            refreshDailyProgress()
            Task {
                do {
                    _ = try await apiClient.saveMealLog(meal)
                    await syncProgressFromBackend()
                } catch {
                    await MainActor.run {
                        self.nutritionErrorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            nutritionErrorMessage = error.localizedDescription
        }
    }

    func deleteMeal(_ meal: MealLog) {
        print("[MealDelete] Delete requested:", meal.id)
        _ = mealLogService.deleteMealLog(id: meal.id, userId: userId)
        refreshDailyProgress()
        print("[MealDelete] Meals remaining:", todaysMeals.count)
        Task {
            do {
                try await apiClient.deleteMealLog(id: meal.id)
                await syncProgressFromBackend()
                print("[MealDelete] Deleted:", meal.id)
            } catch {
                await MainActor.run {
                    self.nutritionErrorMessage = error.localizedDescription
                }
                print("[MealDelete] Failed:", error.localizedDescription)
            }
        }
    }

    func saveSupplement(_ supplement: Supplement) async throws {
        if supplementService.supplements.contains(where: { $0.id == supplement.id }) {
            try await supplementService.update(supplement)
        } else {
            try await supplementService.add(supplement)
        }
    }

    func deleteSupplement(_ supplement: Supplement) async throws {
        try await supplementService.delete(supplement)
    }

    func toggleSupplementActive(_ supplement: Supplement) async throws {
        try await supplementService.toggleActive(supplement)
    }

    func saveHealthCondition(_ condition: HealthCondition) async throws {
        if healthHistoryService.conditions.contains(where: { $0.id == condition.id }) {
            try await healthHistoryService.update(condition)
        } else {
            try await healthHistoryService.add(condition)
        }
    }

    func deleteHealthCondition(_ condition: HealthCondition) async throws {
        try await healthHistoryService.delete(condition)
    }

    func refreshProfileMetadata() async {
        await supplementService.fetch(userId: userId)
        await healthHistoryService.fetch(userId: userId)
    }

    private func syncFromBackendIfPossible() async {
        do {
            let remoteProfile = try await apiClient.fetchNutritionProfile(userId: userId)
            await MainActor.run {
                self.profileService.save(remoteProfile)
                self.profile = remoteProfile
                self.showOnboarding = false
            }
            await syncProgressFromBackend()
        } catch {
        }
    }

    private func syncProgressFromBackend() async {
        guard profile != nil else { return }
        do {
            async let progress = apiClient.fetchNutritionProgress(userId: userId, date: todayDateString())
            async let meals = apiClient.fetchMealLogs(userId: userId, date: todayDateString())
            async let summary = apiClient.fetchWeeklyNutritionSummary(userId: userId)

            let fetchedProgress = try await progress
            let fetchedMeals = try await meals
            let fetchedSummary = try await summary

            await MainActor.run {
                self.dailyProgress = fetchedProgress
                self.todaysMeals = fetchedMeals
                self.mealHistory = self.mealLogService.mealLogs(for: self.userId)
                self.weeklySummary = fetchedSummary
                self.consistencyCard = self.consistencyService.summary(userId: self.userId)
            }
        } catch {
            await MainActor.run {
                self.nutritionErrorMessage = error.localizedDescription
            }
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
