import Foundation

struct RemoteAppStateEnvelope: Codable, Equatable {
    let userId: String
    let payload: AppStateSnapshotPayload
    let createdAt: String?
    let updatedAt: String?
}

struct AppStateSnapshotPayload: Codable, Equatable {
    let baseline: Baseline?
    let baselineCreatedAt: Date?
    let goalConfig: GoalConfig?
    let waterEntries: [StoredWaterProgressEntry]
    let mealLogs: [MealLog]
    let supplementIntakeLogs: [SupplementIntakeLog]
    let journey: JourneyPersistenceSnapshot?
    let adaptiveCoachFeatures: AdaptiveCoachFeatureSnapshot?
}

struct JourneyPersistenceSnapshot: Codable, Equatable {
    let selectedChallengeId: String
    let challenges: [JourneyChallengeStateSnapshot]
}

struct JourneyChallengeStateSnapshot: Codable, Equatable, Identifiable {
    let challengeId: String
    let progress: JourneyProgress?
    let dailyLogs: [DailyJourneyLog]
    let achievements: [JourneyAchievement]

    var id: String { challengeId }
}

struct AdaptiveCoachFeatureSnapshot: Codable, Equatable {
    let savedMeals: [SavedMealForLater]
    let weeklyFocusChips: [String]
}
