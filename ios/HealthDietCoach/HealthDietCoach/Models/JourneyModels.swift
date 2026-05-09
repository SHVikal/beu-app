import Foundation

struct JourneyMilestone: Codable, Equatable, Identifiable {
    let id: String
    let city: String
    let country: String
    let distanceKm: Double
    let symbolName: String
}

struct JourneyChallenge: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let sourceCity: String
    let destinationCity: String
    let totalDistanceKm: Double
    let subtitle: String
    let milestones: [JourneyMilestone]
}

struct DailyJourneyLog: Codable, Equatable, Identifiable {
    let id: String
    let userId: String
    let challengeId: String
    let date: String
    let steps: Int
    let distanceKm: Double
    let pointsEarned: Int
    let createdAt: String
    let updatedAt: String
}

struct JourneyProgress: Codable, Equatable {
    let userId: String
    let challengeId: String
    let startDate: String
    let totalDistanceKm: Double
    let totalSteps: Int
    let lastSyncedDate: String
    let currentCity: String
    let nextCity: String
    let points: Int
    let level: Int
    let title: String
}

struct JourneyAchievement: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let unlocked: Bool
    let progress: Double
    let unlockedAt: String?
    let category: JourneyBadgeCategory
    let unlockCondition: String
}

enum JourneyBadgeCategory: String, Codable, CaseIterable, Identifiable {
    case all
    case earned
    case locked
    case distance
    case city
    case streak
    case steps
    case completion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .earned: return "Earned"
        case .locked: return "Locked"
        case .distance: return "Distance"
        case .city: return "Cities"
        case .streak: return "Streaks"
        case .steps: return "Steps"
        case .completion: return "Completion"
        }
    }
}

struct JourneyLevel: Equatable, Identifiable {
    let id: Int
    let threshold: Int
    let title: String
}

struct JourneyMission: Equatable {
    let title: String
    let stepTarget: Int
    let currentSteps: Int
    let rewardPoints: Int
}

struct JourneyUnlockablesSummary: Equatable {
    let badgesUnlocked: Int
    let badgesTotal: Int
    let titlesUnlocked: Int
    let titlesTotal: Int
    let postcardsUnlocked: Int
    let postcardsTotal: Int
}

struct JourneySnapshot: Equatable {
    let challenge: JourneyChallenge
    let progress: JourneyProgress
    let todayLog: DailyJourneyLog?
    let dailyLogs: [DailyJourneyLog]
    let achievements: [JourneyAchievement]
    let currentMilestone: JourneyMilestone
    let nextMilestone: JourneyMilestone?
    let nextNextMilestone: JourneyMilestone?
    let distanceRemainingKm: Double
    let progressPercent: Double
    let mission: JourneyMission
    let unlockables: JourneyUnlockablesSummary
    let currentLevel: JourneyLevel
    let nextLevel: JourneyLevel?
    let nextLevelProgress: Double
    let stepLengthMeters: Double
    let didCompleteChallenge: Bool
}
