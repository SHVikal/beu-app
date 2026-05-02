import Foundation

@MainActor
final class HealthKitGateway: ObservableObject {
    @Published private(set) var todaySummary: HealthSummary?
    @Published private(set) var recentSummaries: [HealthSummary] = []
    @Published private(set) var stepSeries: [DailyStepCount] = []
    @Published private(set) var isConnected = false
    @Published private(set) var lastSyncLabel = "Using prototype data"

    private let userId: String
    private let manager: HealthKitManager

    init(userId: String = "local-user", manager: HealthKitManager = HealthKitManager()) {
        self.userId = userId
        self.manager = manager
    }

    func refresh() async {
        do {
            try await manager.requestAuthorization()
            async let summary = manager.fetchTodaySummary(userId: userId)
            async let recent = manager.fetchSummaries(userId: userId, days: 7)
            async let series = manager.fetchStepSeries(days: 7)
            let loadedSummary = try await summary
            let loadedRecent = try await recent
            let loadedSeries = try await series
            todaySummary = loadedSummary
            recentSummaries = loadedRecent
            stepSeries = loadedSeries
            isConnected = true
            lastSyncLabel = "Synced just now"
        } catch {
            todaySummary = Self.prototypeSummary(userId: userId)
            recentSummaries = Self.prototypeSummaries(userId: userId)
            stepSeries = Self.prototypeSeries
            isConnected = false
            lastSyncLabel = "Using prototype data"
        }
    }

    var currentSignals: HealthSignals {
        let summary = todaySummary ?? Self.prototypeSummary(userId: userId)
        return HealthSignals(
            sleepHours: summary.sleepHours,
            sleepTarget: 7.5,
            hrv: Int((summary.hrvMs ?? 42).rounded()),
            rhr: Int((summary.restingHeartRateBpm ?? 68).rounded())
        )
    }

    var currentSteps: Int {
        (todaySummary ?? Self.prototypeSummary(userId: userId)).steps
    }

    var readiness: Readiness {
        let today = todaySummary ?? Self.prototypeSummary(userId: userId)
        let summaries = recentSummaries.isEmpty ? Self.prototypeSummaries(userId: userId) : recentSummaries
        return Self.readiness(for: today, within: summaries)
    }

    var weeklyReadiness: [Int] {
        let summaries = recentSummaries.isEmpty ? Self.prototypeSummaries(userId: userId) : recentSummaries
        return summaries.map { summary in Self.readiness(for: summary, within: summaries).score }
    }

    private static func readiness(for summary: HealthSummary, within summaries: [HealthSummary]) -> Readiness {
        let sleepWeight = 35.0
        let hrvWeight = 25.0
        let rhrWeight = 20.0
        let activityWeight = 20.0
        let defaultSleepHours = 7.0
        let neutralSleepScore = 0.85 * sleepWeight

        let recent = summaries.filter { $0.date <= summary.date }.sorted { $0.date < $1.date }
        let prior = recent.filter { $0.date < summary.date }
        let averagesBase = recent.isEmpty ? summaries : recent

        let avgSleep = average(of: averagesBase.compactMap { validSleepHours($0.sleepHours) }) ?? defaultSleepHours
        let avgHRV = average(of: averagesBase.compactMap(\.hrvMs))
        let avgRHR = average(of: averagesBase.compactMap(\.restingHeartRateBpm))
        let avgActiveEnergy = average(of: averagesBase.map(\.activeEnergyKcal).filter { $0 > 0 })
        let yesterdaySummary = prior.last
        let yesterdayActiveEnergy = yesterdaySummary?.activeEnergyKcal

        var rawScore = 0.0
        var availableWeight = 0.0
        var contributingFactors: [String] = []
        var availableSignals: [String] = []
        var missingSignals: [String] = []
        var usedDefaultSleep = false
        var realRecoverySignalCount = 0

        if let actualSleep = validSleepHours(summary.sleepHours) {
            let effectiveAvgSleep = max(avgSleep, defaultSleepHours)
            let sleepScore = min(actualSleep / max(effectiveAvgSleep, 1), 1.0) * sleepWeight
            rawScore += sleepScore
            availableWeight += sleepWeight
            availableSignals.append("sleep")
            realRecoverySignalCount += 1
            contributingFactors.append(actualSleep < effectiveAvgSleep
                ? "Sleep was below your recent average."
                : "Sleep was in line with your recent average.")
        } else {
            rawScore += neutralSleepScore
            availableWeight += sleepWeight
            availableSignals.append("sleep_default")
            usedDefaultSleep = true
            contributingFactors.append("Sleep data was unavailable, so BeU used a neutral 7-hour default.")
        }

        if let latestHRV = summary.hrvMs, let avgHRV, avgHRV > 0 {
            let hrvScore = min(latestHRV / avgHRV, 1.0) * hrvWeight
            rawScore += hrvScore
            availableWeight += hrvWeight
            availableSignals.append("hrv")
            realRecoverySignalCount += 1
            contributingFactors.append(latestHRV >= avgHRV
                ? "HRV is in line with your recent pattern."
                : "HRV is a bit below your recent pattern.")
        } else {
            missingSignals.append("hrv")
            contributingFactors.append("HRV was unavailable, so it was not included.")
        }

        if let latestRHR = summary.restingHeartRateBpm, let avgRHR, latestRHR > 0, avgRHR > 0 {
            let rhrScore = min(avgRHR / latestRHR, 1.0) * rhrWeight
            rawScore += rhrScore
            availableWeight += rhrWeight
            availableSignals.append("resting_heart_rate")
            realRecoverySignalCount += 1
            contributingFactors.append(latestRHR <= avgRHR
                ? "Resting heart rate is in line with your recent pattern."
                : "Resting heart rate is a bit elevated versus your recent pattern.")
        } else {
            missingSignals.append("resting_heart_rate")
            contributingFactors.append("Resting heart rate was unavailable, so it was not included.")
        }

        if let yesterdayActiveEnergy, let avgActiveEnergy, yesterdayActiveEnergy > 0, avgActiveEnergy > 0 {
            let activityRatio = yesterdayActiveEnergy / avgActiveEnergy
            let activityScore: Double
            switch activityRatio {
            case ...1.1:
                activityScore = activityWeight
            case ...1.4:
                activityScore = 16
            case ...1.8:
                activityScore = 12
            default:
                activityScore = 8
            }
            rawScore += activityScore
            availableWeight += activityWeight
            availableSignals.append("yesterday_activity_load")
            realRecoverySignalCount += 1
            contributingFactors.append(activityRatio > 1.4
                ? "Yesterday’s activity load was higher than your recent average."
                : "Yesterday’s activity load was close to your recent average.")
        } else {
            missingSignals.append("yesterday_activity_load")
            contributingFactors.append("Yesterday activity load was unavailable, so it was not included.")
        }

        let normalizedScore = availableWeight > 0 ? Int(((rawScore / availableWeight) * 100).rounded()) : 0
        let clamped = min(max(normalizedScore, 0), 100)

        let status: ReadinessStatus
        if realRecoverySignalCount < 2 {
            status = .limitedData
        } else if clamped >= 80 {
            status = .high
        } else if clamped >= 60 {
            status = .good
        } else if clamped >= 45 {
            status = .moderate
        } else {
            status = .low
        }

        let message: String
        switch status {
        case .limitedData:
            message = "Some recovery data is still syncing, so today’s plan uses your goal and activity progress."
        case .high where usedDefaultSleep:
            message = "Recovery looks good based on available data. Sleep was estimated using a neutral default because Apple Health sleep data was unavailable."
        case .good where usedDefaultSleep:
            message = "Recovery looks good based on available data. Sleep was estimated using a neutral default because Apple Health sleep data was unavailable."
        case .high:
            message = "Recovery looks strong. You can follow your normal plan today."
        case .good:
            message = "Recovery looks good. Keep your plan balanced today."
        case .moderate:
            message = "Recovery is mixed. Keep activity moderate today."
        case .low:
            message = "Recovery looks low. Keep movement light and prioritize recovery."
        }

        return Readiness(
            score: clamped,
            status: status,
            oneLineMessage: message,
            contributingFactors: contributingFactors,
            usedDefaultSleep: usedDefaultSleep,
            availableSignals: availableSignals,
            missingSignals: missingSignals
        )
    }

    private static func validSleepHours(_ sleepHours: Double) -> Double? {
        guard sleepHours >= 3.0 else { return nil }
        return sleepHours
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func prototypeSummary(userId: String) -> HealthSummary {
        HealthSummary(
            userId: userId,
            date: ISODateOnlyFormatter.shared.string(from: Date()),
            steps: 3200,
            activeEnergyKcal: 320,
            basalEnergyKcal: 1480,
            workoutCount: 0,
            workoutMinutes: 0,
            workoutEnergyKcal: 0,
            totalEnergyBurnedKcal: 1800,
            estimatedTotalBurnKcal: 1800,
            sleepHours: 6.1,
            restingHeartRateBpm: 68,
            hrvMs: 42,
            weightKg: 72,
            heightCm: 165
        )
    }

    static var prototypeSeries: [DailyStepCount] {
        let calendar = Calendar.current
        let values = [6800, 7200, 6400, 7600, 7100, 7000, 3200]
        return values.enumerated().compactMap { index, steps in
            guard let date = calendar.date(byAdding: .day, value: -(values.count - 1 - index), to: calendar.startOfDay(for: Date())) else {
                return nil
            }
            return DailyStepCount(date: date, steps: steps)
        }
    }

    static func prototypeSummaries(userId: String) -> [HealthSummary] {
        let calendar = Calendar.current
        let steps = [6800, 7200, 6400, 7600, 7100, 7000, 3200]
        let sleeps = [7.4, 7.2, 6.9, 7.5, 7.1, 6.8, 6.1]
        let hrv = [46.0, 44.0, 43.0, 47.0, 45.0, 44.0, 42.0]
        let rhr = [64.0, 65.0, 66.0, 63.0, 64.0, 66.0, 68.0]
        return steps.enumerated().compactMap { index, daySteps in
            guard let date = calendar.date(byAdding: .day, value: -(steps.count - 1 - index), to: calendar.startOfDay(for: Date())) else {
                return nil
            }
            return HealthSummary(
                userId: userId,
                date: ISODateOnlyFormatter.shared.string(from: date),
                steps: daySteps,
                activeEnergyKcal: Double(daySteps) * 0.09,
                basalEnergyKcal: 1480,
                workoutCount: daySteps > 7000 ? 1 : 0,
                workoutMinutes: daySteps > 7000 ? 28 : 0,
                workoutEnergyKcal: daySteps > 7000 ? 180 : 0,
                totalEnergyBurnedKcal: 1480 + (Double(daySteps) * 0.09),
                estimatedTotalBurnKcal: 1480 + (Double(daySteps) * 0.09),
                sleepHours: sleeps[index],
                restingHeartRateBpm: rhr[index],
                hrvMs: hrv[index],
                weightKg: 72,
                heightCm: 165
            )
        }
    }
}
