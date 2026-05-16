import Foundation

final class JourneyService {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    let levels: [JourneyLevel] = [
        JourneyLevel(id: 1, threshold: 0, title: "City Starter"),
        JourneyLevel(id: 2, threshold: 500, title: "Street Walker"),
        JourneyLevel(id: 3, threshold: 1200, title: "Desert Voyager"),
        JourneyLevel(id: 4, threshold: 2500, title: "Skyline Scout"),
        JourneyLevel(id: 5, threshold: 4000, title: "Border Crosser"),
        JourneyLevel(id: 6, threshold: 6500, title: "Nomad Navigator"),
        JourneyLevel(id: 7, threshold: 9000, title: "Globe Trekker"),
        JourneyLevel(id: 8, threshold: 12000, title: "Continental Explorer"),
        JourneyLevel(id: 9, threshold: 16000, title: "Route Master"),
        JourneyLevel(id: 10, threshold: 21000, title: "Berlin Finisher"),
    ]

    let challenges: [JourneyChallenge] = [
        JourneyChallenge(
            id: "dubai-berlin",
            title: "Dubai to Berlin",
            sourceCity: "Dubai",
            destinationCity: "Berlin",
            totalDistanceKm: 4700,
            subtitle: "Walk your way across iconic cities.",
            milestones: [
                .init(id: "dubai", city: "Dubai", country: "United Arab Emirates", distanceKm: 0, symbolName: "sun.max"),
                .init(id: "riyadh", city: "Riyadh", country: "Saudi Arabia", distanceKm: 1000, symbolName: "building.columns"),
                .init(id: "ankara", city: "Ankara", country: "Turkey", distanceKm: 2400, symbolName: "building.2.crop.circle"),
                .init(id: "budapest", city: "Budapest", country: "Hungary", distanceKm: 3300, symbolName: "tram.fill"),
                .init(id: "vienna", city: "Vienna", country: "Austria", distanceKm: 3900, symbolName: "music.note.house"),
                .init(id: "berlin", city: "Berlin", country: "Germany", distanceKm: 4700, symbolName: "ferry.fill"),
            ]
        ),
        JourneyChallenge(
            id: "dubai-istanbul",
            title: "Dubai to Istanbul",
            sourceCity: "Dubai",
            destinationCity: "Istanbul",
            totalDistanceKm: 3000,
            subtitle: "Trace a pink route to the Bosphorus.",
            milestones: [
                .init(id: "dubai", city: "Dubai", country: "United Arab Emirates", distanceKm: 0, symbolName: "sun.max"),
                .init(id: "riyadh", city: "Riyadh", country: "Saudi Arabia", distanceKm: 900, symbolName: "building.columns"),
                .init(id: "amman", city: "Amman", country: "Jordan", distanceKm: 1600, symbolName: "moon.stars.fill"),
                .init(id: "antalya", city: "Antalya", country: "Turkey", distanceKm: 2300, symbolName: "water.waves"),
                .init(id: "istanbul", city: "Istanbul", country: "Turkey", distanceKm: 3000, symbolName: "ferry.fill"),
            ]
        ),
        JourneyChallenge(
            id: "dubai-paris",
            title: "Dubai to Paris",
            sourceCity: "Dubai",
            destinationCity: "Paris",
            totalDistanceKm: 5250,
            subtitle: "A long pink trail through layered capitals.",
            milestones: [
                .init(id: "dubai", city: "Dubai", country: "United Arab Emirates", distanceKm: 0, symbolName: "sun.max"),
                .init(id: "riyadh", city: "Riyadh", country: "Saudi Arabia", distanceKm: 950, symbolName: "building.columns"),
                .init(id: "cairo", city: "Cairo", country: "Egypt", distanceKm: 1850, symbolName: "pyramid.fill"),
                .init(id: "athens", city: "Athens", country: "Greece", distanceKm: 3050, symbolName: "building.columns.circle"),
                .init(id: "rome", city: "Rome", country: "Italy", distanceKm: 4150, symbolName: "sparkles"),
                .init(id: "paris", city: "Paris", country: "France", distanceKm: 5250, symbolName: "camera.macro"),
            ]
        ),
        JourneyChallenge(
            id: "dubai-rome",
            title: "Dubai to Rome",
            sourceCity: "Dubai",
            destinationCity: "Rome",
            totalDistanceKm: 4350,
            subtitle: "Walk toward marble streets and evening aperitivo.",
            milestones: [
                .init(id: "dubai", city: "Dubai", country: "United Arab Emirates", distanceKm: 0, symbolName: "sun.max"),
                .init(id: "riyadh", city: "Riyadh", country: "Saudi Arabia", distanceKm: 900, symbolName: "building.columns"),
                .init(id: "cairo", city: "Cairo", country: "Egypt", distanceKm: 1750, symbolName: "pyramid.fill"),
                .init(id: "athens", city: "Athens", country: "Greece", distanceKm: 2850, symbolName: "building.columns.circle"),
                .init(id: "naples", city: "Naples", country: "Italy", distanceKm: 3700, symbolName: "leaf.fill"),
                .init(id: "rome", city: "Rome", country: "Italy", distanceKm: 4350, symbolName: "sparkles"),
            ]
        ),
        JourneyChallenge(
            id: "dubai-london",
            title: "Dubai to London",
            sourceCity: "Dubai",
            destinationCity: "London",
            totalDistanceKm: 5500,
            subtitle: "Travel from Gulf glow to London lights.",
            milestones: [
                .init(id: "dubai", city: "Dubai", country: "United Arab Emirates", distanceKm: 0, symbolName: "sun.max"),
                .init(id: "riyadh", city: "Riyadh", country: "Saudi Arabia", distanceKm: 1000, symbolName: "building.columns"),
                .init(id: "istanbul", city: "Istanbul", country: "Turkey", distanceKm: 2500, symbolName: "ferry.fill"),
                .init(id: "vienna", city: "Vienna", country: "Austria", distanceKm: 3800, symbolName: "music.note.house"),
                .init(id: "brussels", city: "Brussels", country: "Belgium", distanceKm: 4700, symbolName: "tram.fill"),
                .init(id: "london", city: "London", country: "United Kingdom", distanceKm: 5500, symbolName: "crown.fill"),
            ]
        ),
    ]

    func selectedChallenge(for userId: String) -> JourneyChallenge {
        let selectedID = userDefaults.string(forKey: selectedChallengeKey(for: userId)) ?? challenges[0].id
        return challenges.first(where: { $0.id == selectedID }) ?? challenges[0]
    }

    func selectChallenge(_ challengeID: String, for userId: String) {
        userDefaults.set(challengeID, forKey: selectedChallengeKey(for: userId))
    }

    func persistenceSnapshot(for userId: String) -> JourneyPersistenceSnapshot {
        JourneyPersistenceSnapshot(
            selectedChallengeId: selectedChallenge(for: userId).id,
            challenges: challenges.map { challenge in
                JourneyChallengeStateSnapshot(
                    challengeId: challenge.id,
                    progress: existingProgress(for: userId, challengeID: challenge.id),
                    dailyLogs: dailyLogs(for: userId, challengeID: challenge.id),
                    achievements: achievements(for: userId, challengeID: challenge.id)
                )
            }
        )
    }

    func restore(snapshot: JourneyPersistenceSnapshot?, for userId: String) {
        guard let snapshot else {
            return
        }

        userDefaults.set(snapshot.selectedChallengeId, forKey: selectedChallengeKey(for: userId))

        for challenge in challenges {
            let state = snapshot.challenges.first(where: { $0.challengeId == challenge.id })
            if let progress = state?.progress, let data = try? encoder.encode(progress) {
                userDefaults.set(data, forKey: progressKey(for: userId, challengeID: challenge.id))
            } else {
                userDefaults.removeObject(forKey: progressKey(for: userId, challengeID: challenge.id))
            }

            if let logs = state?.dailyLogs, let data = try? encoder.encode(logs) {
                userDefaults.set(data, forKey: logsKey(for: userId, challengeID: challenge.id))
            } else {
                userDefaults.removeObject(forKey: logsKey(for: userId, challengeID: challenge.id))
            }

            if let achievements = state?.achievements, let data = try? encoder.encode(achievements) {
                userDefaults.set(data, forKey: achievementsKey(for: userId, challengeID: challenge.id))
            } else {
                userDefaults.removeObject(forKey: achievementsKey(for: userId, challengeID: challenge.id))
            }
        }
    }

    func syncJourneyProgress(
        userId: String,
        challengeID: String,
        summaries: [HealthSummary],
        todaySummary: HealthSummary?,
        heightCm: Int?,
        dailyStepGoal: Int
    ) -> JourneySnapshot {
        let challenge = challenges.first(where: { $0.id == challengeID }) ?? challenges[0]
        let stepLengthMeters = estimatedStepLengthMeters(heightCm: heightCm)
        let challengeStartDate = existingProgress(for: userId, challengeID: challenge.id)?.startDate ?? (summaries.map(\.date).min() ?? Date().localYYYYMMDD)
        var logs = dailyLogs(for: userId, challengeID: challenge.id)
        let now = ISO8601DateFormatter().string(from: Date())

        for summary in summaries {
            let newLog = DailyJourneyLog(
                id: "\(userId)-\(challenge.id)-\(summary.date)",
                userId: userId,
                challengeId: challenge.id,
                date: summary.date,
                steps: max(summary.steps, 0),
                distanceKm: dailyDistanceKm(steps: max(summary.steps, 0), stepLengthMeters: stepLengthMeters),
                pointsEarned: 0,
                createdAt: logs.first(where: { $0.date == summary.date })?.createdAt ?? now,
                updatedAt: now
            )
            logs.removeAll { $0.date == summary.date }
            logs.append(newLog)
        }

        logs.sort { $0.date < $1.date }

        let recalculated = recalculateLogs(logs, dailyStepGoal: dailyStepGoal, milestones: challenge.milestones)
        let totalDistanceKm = recalculated.reduce(0) { $0 + $1.distanceKm }
        let totalSteps = recalculated.reduce(0) { $0 + $1.steps }
        let totalPoints = recalculated.reduce(0) { $0 + $1.pointsEarned }
        let currentMilestone = calculateCurrentCity(totalDistanceKm: totalDistanceKm, challenge: challenge)
        let nextMilestone = calculateNextCity(totalDistanceKm: totalDistanceKm, challenge: challenge)
        let nextNextMilestone = nextMilestone.flatMap { next in challenge.milestones.drop { $0.distanceKm <= next.distanceKm }.first }
        let currentLevel = calculateLevel(points: totalPoints)
        let nextLevel = levels.first(where: { $0.threshold > totalPoints })
        let nextLevelProgress = progressToNextLevel(points: totalPoints, currentLevel: currentLevel, nextLevel: nextLevel)

        let progress = JourneyProgress(
            userId: userId,
            challengeId: challenge.id,
            startDate: challengeStartDate,
            totalDistanceKm: totalDistanceKm,
            totalSteps: totalSteps,
            lastSyncedDate: todaySummary?.date ?? Date().localYYYYMMDD,
            currentCity: currentMilestone.city,
            nextCity: nextMilestone?.city ?? challenge.destinationCity,
            points: totalPoints,
            level: currentLevel.id,
            title: currentLevel.title
        )
        persist(progress: progress, userId: userId, challengeID: challenge.id)
        persist(logs: recalculated, userId: userId, challengeID: challenge.id)

        let achievements = getAchievements(progress: progress, logs: recalculated, challenge: challenge)
        persist(achievements: achievements, userId: userId, challengeID: challenge.id)

        let todayLog = recalculated.first(where: { $0.date == Date().localYYYYMMDD })
        let totalDistance = max(challenge.totalDistanceKm, 1)

        return JourneySnapshot(
            challenge: challenge,
            progress: progress,
            todayLog: todayLog,
            dailyLogs: recalculated,
            achievements: achievements,
            currentMilestone: currentMilestone,
            nextMilestone: nextMilestone,
            nextNextMilestone: nextNextMilestone,
            distanceRemainingKm: max(challenge.totalDistanceKm - totalDistanceKm, 0),
            progressPercent: min(max(totalDistanceKm / totalDistance, 0), 1),
            mission: dailyMission(todaySteps: todaySummary?.steps ?? 0, dailyStepGoal: dailyStepGoal),
            unlockables: unlockablesSummary(achievements: achievements, totalPoints: totalPoints, totalDistanceKm: totalDistanceKm, challenge: challenge),
            currentLevel: currentLevel,
            nextLevel: nextLevel,
            nextLevelProgress: nextLevelProgress,
            stepLengthMeters: stepLengthMeters,
            didCompleteChallenge: totalDistanceKm >= challenge.totalDistanceKm
        )
    }

    func getJourneyProgress(userId: String, challengeID: String) -> JourneyProgress? {
        existingProgress(for: userId, challengeID: challengeID)
    }

    func getDailyJourneyLogs(userId: String, challengeID: String) -> [DailyJourneyLog] {
        dailyLogs(for: userId, challengeID: challengeID)
    }

    func calculateCurrentCity(totalDistanceKm: Double, challenge: JourneyChallenge) -> JourneyMilestone {
        challenge.milestones.last(where: { totalDistanceKm >= $0.distanceKm }) ?? challenge.milestones[0]
    }

    func calculateNextCity(totalDistanceKm: Double, challenge: JourneyChallenge) -> JourneyMilestone? {
        challenge.milestones.first(where: { totalDistanceKm < $0.distanceKm })
    }

    func calculatePoints(steps: Int, didHitGoal: Bool, unlockedCityCount: Int, streakBonusEligible: Bool) -> Int {
        var points = max(steps / 100, 0)
        if didHitGoal {
            points += 50
        }
        if streakBonusEligible {
            points += 100
        }
        points += unlockedCityCount * 250
        return points
    }

    func calculateLevel(points: Int) -> JourneyLevel {
        levels.last(where: { points >= $0.threshold }) ?? levels[0]
    }

    func getAchievements(progress: JourneyProgress, logs: [DailyJourneyLog], challenge: JourneyChallenge) -> [JourneyAchievement] {
        let totalDistance = progress.totalDistanceKm
        let longestStreak = longestWalkingStreak(logs: logs)
        let maxSteps = logs.map(\.steps).max() ?? 0
        let unlockedCities = Set(challenge.milestones.filter { totalDistance >= $0.distanceKm }.map(\.city))
        let unlockedAtByCity = unlockedDateByCity(logs: logs, challenge: challenge)
        let completedChallengeCount = challenges.filter { challenge in
            let distance = existingProgress(for: progress.userId, challengeID: challenge.id)?.totalDistanceKm ?? 0
            return distance >= challenge.totalDistanceKm
        }.count

        let cityMilestones = challenge.milestones.dropFirst().map { milestone in
            JourneyAchievement(
                id: "city-\(challenge.id)-\(milestone.id)",
                title: "\(milestone.city) unlocked",
                description: "Reach \(milestone.city) on the \(challenge.title) route.",
                iconName: milestone.symbolName,
                unlocked: unlockedCities.contains(milestone.city),
                progress: min(max(totalDistance / max(milestone.distanceKm, 1), 0), 1),
                unlockedAt: unlockedCities.contains(milestone.city) ? unlockedAtByCity[milestone.city] : nil,
                category: .city,
                unlockCondition: "Reach \(Int(milestone.distanceKm)) km on this route."
            )
        }

        let staticBadges: [JourneyAchievement] = [
            makeDistanceBadge(id: "distance-10", title: "First 10 km", target: 10, totalDistance: totalDistance, logs: logs),
            makeDistanceBadge(id: "distance-100", title: "First 100 km", target: 100, totalDistance: totalDistance, logs: logs),
            makeDistanceBadge(id: "distance-500", title: "First 500 km", target: 500, totalDistance: totalDistance, logs: logs),
            makeDistanceBadge(id: "distance-1000", title: "First 1000 km", target: 1000, totalDistance: totalDistance, logs: logs),
            makeDistanceBadge(id: "distance-2500", title: "First 2500 km", target: 2500, totalDistance: totalDistance, logs: logs),
            makeStreakBadge(id: "streak-3", title: "3-day streak", target: 3, longestStreak: longestStreak, logs: logs),
            makeStreakBadge(id: "streak-7", title: "7-day streak", target: 7, longestStreak: longestStreak, logs: logs),
            makeStreakBadge(id: "streak-30", title: "30-day streak", target: 30, longestStreak: longestStreak, logs: logs),
            makeStepsBadge(id: "steps-10000", title: "10,000 steps in a day", target: 10_000, maxSteps: maxSteps, logs: logs),
            makeStepsBadge(id: "steps-15000", title: "15,000 steps in a day", target: 15_000, maxSteps: maxSteps, logs: logs),
            makeStepsBadge(id: "steps-20000", title: "20,000 steps in a day", target: 20_000, maxSteps: maxSteps, logs: logs),
            JourneyAchievement(
                id: "completion-first",
                title: "First route completed",
                description: "Finish one Travel Trail route.",
                iconName: "flag.checkered.2.crossed",
                unlocked: completedChallengeCount >= 1,
                progress: min(Double(completedChallengeCount) / 1.0, 1),
                unlockedAt: completedChallengeCount >= 1 ? progress.lastSyncedDate : nil,
                category: .completion,
                unlockCondition: "Finish any one route."
            ),
            JourneyAchievement(
                id: "completion-three",
                title: "3 routes explored",
                description: "Complete three journey routes.",
                iconName: "globe.europe.africa.fill",
                unlocked: completedChallengeCount >= 3,
                progress: min(Double(completedChallengeCount) / 3.0, 1),
                unlockedAt: completedChallengeCount >= 3 ? progress.lastSyncedDate : nil,
                category: .completion,
                unlockCondition: "Finish three routes."
            ),
            JourneyAchievement(
                id: "completion-five",
                title: "5 routes explored",
                description: "Complete all five journey routes.",
                iconName: "sparkles",
                unlocked: completedChallengeCount >= 5,
                progress: min(Double(completedChallengeCount) / 5.0, 1),
                unlockedAt: completedChallengeCount >= 5 ? progress.lastSyncedDate : nil,
                category: .completion,
                unlockCondition: "Finish all five routes."
            ),
        ]

        return (staticBadges + cityMilestones)
    }

    private func recalculateLogs(_ logs: [DailyJourneyLog], dailyStepGoal: Int, milestones: [JourneyMilestone]) -> [DailyJourneyLog] {
        var runningDistance = 0.0
        var streak = 0
        var result: [DailyJourneyLog] = []

        for log in logs.sorted(by: { $0.date < $1.date }) {
            streak = log.steps > 0 ? streak + 1 : 0
            let previousDistance = runningDistance
            runningDistance += log.distanceKm
            let unlockedBefore = milestones.filter { previousDistance >= $0.distanceKm }.count
            let unlockedAfter = milestones.filter { runningDistance >= $0.distanceKm }.count
            let points = calculatePoints(
                steps: log.steps,
                didHitGoal: log.steps >= dailyStepGoal,
                unlockedCityCount: max(unlockedAfter - unlockedBefore, 0),
                streakBonusEligible: streak == 7
            )

            result.append(
                DailyJourneyLog(
                    id: log.id,
                    userId: log.userId,
                    challengeId: log.challengeId,
                    date: log.date,
                    steps: log.steps,
                    distanceKm: log.distanceKm,
                    pointsEarned: points,
                    createdAt: log.createdAt,
                    updatedAt: log.updatedAt
                )
            )
        }

        return result
    }

    private func dailyMission(todaySteps: Int, dailyStepGoal: Int) -> JourneyMission {
        let reward = max(dailyStepGoal / 100, 1) + 50
        return JourneyMission(
            title: "Walk \(dailyStepGoal.formatted()) steps to earn \(reward) XP.",
            stepTarget: dailyStepGoal,
            currentSteps: todaySteps,
            rewardPoints: reward
        )
    }

    private func unlockablesSummary(achievements: [JourneyAchievement], totalPoints: Int, totalDistanceKm: Double, challenge: JourneyChallenge) -> JourneyUnlockablesSummary {
        JourneyUnlockablesSummary(
            badgesUnlocked: achievements.filter(\.unlocked).count,
            badgesTotal: achievements.count,
            titlesUnlocked: levels.filter { totalPoints >= $0.threshold }.count,
            titlesTotal: levels.count,
            postcardsUnlocked: challenge.milestones.filter { totalDistanceKm >= $0.distanceKm }.count,
            postcardsTotal: challenge.milestones.count
        )
    }

    private func progressToNextLevel(points: Int, currentLevel: JourneyLevel, nextLevel: JourneyLevel?) -> Double {
        guard let nextLevel else { return 1 }
        let span = max(nextLevel.threshold - currentLevel.threshold, 1)
        return min(max(Double(points - currentLevel.threshold) / Double(span), 0), 1)
    }

    private func dailyDistanceKm(steps: Int, stepLengthMeters: Double) -> Double {
        (Double(steps) * stepLengthMeters) / 1000.0
    }

    private func estimatedStepLengthMeters(heightCm: Int?) -> Double {
        guard let heightCm, heightCm > 0 else { return 0.75 }
        return Double(heightCm) * 0.00415
    }

    private func longestWalkingStreak(logs: [DailyJourneyLog]) -> Int {
        var longest = 0
        var current = 0
        for log in logs.sorted(by: { $0.date < $1.date }) {
            if log.steps > 0 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private func unlockedDateForDistance(logs: [DailyJourneyLog], distance: Double) -> String? {
        var runningDistance = 0.0
        for log in logs.sorted(by: { $0.date < $1.date }) {
            runningDistance += log.distanceKm
            if runningDistance >= distance {
                return log.date
            }
        }
        return nil
    }

    private func unlockedDateByCity(logs: [DailyJourneyLog], challenge: JourneyChallenge) -> [String: String] {
        var result: [String: String] = [:]
        var runningDistance = 0.0
        for log in logs.sorted(by: { $0.date < $1.date }) {
            runningDistance += log.distanceKm
            for milestone in challenge.milestones where result[milestone.city] == nil && runningDistance >= milestone.distanceKm {
                result[milestone.city] = log.date
            }
        }
        return result
    }

    private func unlockedDateForStreak(logs: [DailyJourneyLog], target: Int) -> String? {
        var streak = 0
        for log in logs.sorted(by: { $0.date < $1.date }) {
            streak = log.steps > 0 ? streak + 1 : 0
            if streak >= target {
                return log.date
            }
        }
        return nil
    }

    private func makeDistanceBadge(id: String, title: String, target: Double, totalDistance: Double, logs: [DailyJourneyLog]) -> JourneyAchievement {
        JourneyAchievement(
            id: id,
            title: title,
            description: "Cover \(Int(target)) km on any route.",
            iconName: "map.fill",
            unlocked: totalDistance >= target,
            progress: min(max(totalDistance / target, 0), 1),
            unlockedAt: totalDistance >= target ? unlockedDateForDistance(logs: logs, distance: target) : nil,
            category: .distance,
            unlockCondition: "Reach \(Int(target)) km total on this route."
        )
    }

    private func makeStreakBadge(id: String, title: String, target: Int, longestStreak: Int, logs: [DailyJourneyLog]) -> JourneyAchievement {
        JourneyAchievement(
            id: id,
            title: title,
            description: "Walk for \(target) days in a row.",
            iconName: "flame.fill",
            unlocked: longestStreak >= target,
            progress: min(max(Double(longestStreak) / Double(target), 0), 1),
            unlockedAt: longestStreak >= target ? unlockedDateForStreak(logs: logs, target: target) : nil,
            category: .streak,
            unlockCondition: "Walk at least one step for \(target) consecutive days."
        )
    }

    private func makeStepsBadge(id: String, title: String, target: Int, maxSteps: Int, logs: [DailyJourneyLog]) -> JourneyAchievement {
        JourneyAchievement(
            id: id,
            title: title,
            description: "Hit \(target.formatted()) steps in a single day.",
            iconName: "figure.walk.motion",
            unlocked: maxSteps >= target,
            progress: min(max(Double(maxSteps) / Double(target), 0), 1),
            unlockedAt: maxSteps >= target ? logs.first(where: { $0.steps >= target })?.date : nil,
            category: .steps,
            unlockCondition: "Log \(target.formatted()) steps in one day."
        )
    }

    private func existingProgress(for userId: String, challengeID: String) -> JourneyProgress? {
        guard let data = userDefaults.data(forKey: progressKey(for: userId, challengeID: challengeID)),
              let progress = try? decoder.decode(JourneyProgress.self, from: data) else {
            return nil
        }
        return progress
    }

    private func dailyLogs(for userId: String, challengeID: String) -> [DailyJourneyLog] {
        guard let data = userDefaults.data(forKey: logsKey(for: userId, challengeID: challengeID)),
              let logs = try? decoder.decode([DailyJourneyLog].self, from: data) else {
            return []
        }
        return logs.sorted { $0.date < $1.date }
    }

    private func achievements(for userId: String, challengeID: String) -> [JourneyAchievement] {
        guard let data = userDefaults.data(forKey: achievementsKey(for: userId, challengeID: challengeID)),
              let achievements = try? decoder.decode([JourneyAchievement].self, from: data) else {
            return []
        }
        return achievements
    }

    private func persist(progress: JourneyProgress, userId: String, challengeID: String) {
        if let data = try? encoder.encode(progress) {
            userDefaults.set(data, forKey: progressKey(for: userId, challengeID: challengeID))
        }
    }

    private func persist(logs: [DailyJourneyLog], userId: String, challengeID: String) {
        if let data = try? encoder.encode(logs) {
            userDefaults.set(data, forKey: logsKey(for: userId, challengeID: challengeID))
        }
    }

    private func persist(achievements: [JourneyAchievement], userId: String, challengeID: String) {
        if let data = try? encoder.encode(achievements) {
            userDefaults.set(data, forKey: achievementsKey(for: userId, challengeID: challengeID))
        }
    }

    private func selectedChallengeKey(for userId: String) -> String {
        "journeySelectedChallenge_\(userId)"
    }

    private func progressKey(for userId: String, challengeID: String) -> String {
        "journeyProgress_\(userId)_\(challengeID)"
    }

    private func logsKey(for userId: String, challengeID: String) -> String {
        "journeyLogs_\(userId)_\(challengeID)"
    }

    private func achievementsKey(for userId: String, challengeID: String) -> String {
        "journeyAchievements_\(userId)_\(challengeID)"
    }
}
