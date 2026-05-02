import Foundation
import HealthKit

struct HealthDebugSnapshot {
    let healthDataAvailable: Bool
    let stepTypeAvailable: Bool
    let steps: Int
    let sleepHours: Double
    let averageHeartRateBpm: Double?
    let stepSeriesCount: Int
    let stepSeries: [DailyStepCount]
    let permissionLines: [String]
    let guidanceLines: [String]
    let lastSyncAt: Date
}

struct HealthStepDebugSnapshot {
    let healthDataAvailable: Bool
    let stepTypeAvailable: Bool
    let todaySteps: Int
    let stepSeries: [DailyStepCount]
    let permissionLines: [String]
    let guidanceLines: [String]
    let lastSyncAt: Date
    let lastErrorMessage: String?
}

struct DailyStepCount: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let steps: Int
}

enum HealthKitError: LocalizedError {
    case healthDataUnavailable
    case stepTypeUnavailable
    case unsupportedType
    case noData

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .stepTypeUnavailable:
            return "Step count type is unavailable on this device."
        case .unsupportedType:
            return "One or more HealthKit data types are unavailable."
        case .noData:
            return "No health data available yet. Open Apple Health and ensure data is being recorded."
        }
    }
}

final class HealthKitManager {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    init() {
        #if targetEnvironment(simulator)
        print("Running on simulator — HealthKit data may be unavailable")
        #endif

        if !HKHealthStore.isHealthDataAvailable() {
            print("Health data not available on this device")
        } else {
            print("Health data is available on this device")
        }
    }

    func requestAuthorization() async throws {
        if Self.isSimulator {
            print("Skipping HealthKit authorization on simulator")
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available on this device")
            throw HealthKitError.healthDataUnavailable
        }

        let objectTypes = requiredReadTypes()

        guard !objectTypes.isEmpty else {
            throw HealthKitError.unsupportedType
        }

        print("Requesting HealthKit read authorization for \(objectTypes.count) types")
        try await store.requestAuthorization(toShare: [], read: objectTypes)
        print("HealthKit permission success: true")
        logAuthorizationStatuses(for: objectTypes)
    }

    func fetchSummaries(userId: String, days: Int = 30) async throws -> [HealthSummary] {
        if Self.isSimulator {
            return Self.mockSummaries(userId: userId, days: days)
        }

        let recentSummaries = try await fetchRollingSummaries(userId: userId, days: days)
        let recentNonEmptySummaries = recentSummaries.filter(Self.hasMeaningfulData)
        if !recentNonEmptySummaries.isEmpty {
            // Preserve the full recent calendar window, including legitimate
            // zero-step/low-activity days, so weekly trends use consecutive
            // day buckets instead of skipping quiet days.
            return recentSummaries
        }

        // If there is no data inside the primary lookback window, search
        // backwards in chunks and return the most recent meaningful days
        // instead of blank calendar placeholders.
        let chunkSize = max(days, 30)
        let maxLookbackDays = 365

        for startOffset in stride(from: days, through: maxLookbackDays - 1, by: chunkSize) {
            let chunk = try await fetchRollingSummaries(
                userId: userId,
                days: chunkSize,
                startOffset: startOffset
            )
            let nonEmptyChunk = chunk.filter(Self.hasMeaningfulData)

            if !nonEmptyChunk.isEmpty {
                return Array(nonEmptyChunk.suffix(days))
            }
        }

        // Return the recent window even if it is empty so the UI can still
        // render a graceful state and debug which signals are missing.
        return recentSummaries
    }

    func fetchTodaySummary(userId: String) async throws -> HealthSummary {
        try await fetchDailySummary(for: calendar.startOfDay(for: Date()), userId: userId)
    }

    func fetchTodaySteps() async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.stepTypeUnavailable
        }

        let startOfDay = calendar.startOfDay(for: Date())
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endDate,
            options: .strictStartDate
        )

        print("[HealthKit] Fetching today steps...")
        print("[HealthKit] Date range: \(startOfDay) -> \(endDate)")

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    print("[HealthKit] Steps query error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?
                    .sumQuantity()?
                    .doubleValue(for: HKUnit.count()) ?? 0

                print("[HealthKit] Today steps fetched: \(steps)")
                if steps == 0 {
                    print("[HealthKit] No data found for today steps")
                }
                continuation.resume(returning: steps)
            }

            store.execute(query)
        }
    }

    func fetchSteps(for date: Date) async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.stepTypeUnavailable
        }

        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.healthDataUnavailable
        }

        let queryEnd = min(endOfDay, Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: queryEnd,
            options: .strictStartDate
        )

        print("[HealthKit] Fetching steps for \(startOfDay)")
        print("[HealthKit] Date range: \(startOfDay) -> \(queryEnd)")

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    print("[HealthKit] Historical steps query error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?
                    .sumQuantity()?
                    .doubleValue(for: HKUnit.count()) ?? 0

                print("[HealthKit] Steps for \(startOfDay): \(steps)")
                continuation.resume(returning: steps)
            }

            store.execute(query)
        }
    }

    func fetchStepSeries(days: Int = 7) async throws -> [DailyStepCount] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataUnavailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.stepTypeUnavailable
        }

        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: endDate)) ?? calendar.startOfDay(for: endDate)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let anchorDate = calendar.startOfDay(for: endDate)
        let interval = DateComponents(day: 1)

        print("[HealthKit] Fetching step series for last \(days) days")
        print("[HealthKit] Date range: \(startDate) -> \(endDate)")

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    print("[HealthKit] Step series error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                var output: [DailyStepCount] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let count = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    output.append(DailyStepCount(date: statistics.startDate, steps: Int(count.rounded())))
                    print("[HealthKit] Step bucket \(statistics.startDate): \(count)")
                }

                if output.isEmpty {
                    print("[HealthKit] No data found for step series")
                }

                continuation.resume(returning: output)
            }

            store.execute(query)
        }
    }

    func debugFetchSnapshot(userId: String) async throws -> HealthDebugSnapshot {
        let startOfDay = calendar.startOfDay(for: Date())
        let queryEnd = Date()
        print("Running HealthKit debug fetch for user \(userId)")
        print("Querying from: \(startOfDay) to: \(queryEnd)")
        let stepTypeAvailable = HKQuantityType.quantityType(forIdentifier: .stepCount) != nil

        async let summary = fetchDailySummary(for: startOfDay, userId: userId)
        async let todaySteps = fetchTodaySteps()
        async let stepSeries = fetchStepSeries(days: 7)
        async let heartRate = averageQuantity(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: startOfDay,
            end: queryEnd,
            label: "heart rate"
        )

        let dailySummary = try await summary
        let stepCount = try await todaySteps
        let series = try await stepSeries
        let averageHR = try await heartRate
        let permissionLines = [
            "HealthKit read access is validated using query results, not authorizationStatus(for:).",
            "Today steps query returned \(Int(stepCount.rounded())) steps.",
            "7-day steps query returned \(series.count) daily buckets."
        ]

        print("Health debug snapshot -> steps: \(stepCount), sleep: \(dailySummary.sleepHours), heartRate: \(averageHR?.description ?? "nil")")

        let guidanceLines: [String]
        if stepCount == 0 {
            guidanceLines = [
                "BeU could not read step data. Check Settings > Privacy & Security > Health > BeU and ensure Steps is enabled.",
                "Apple may hide Health data from apps if read permission was denied.",
                "Try deleting and reinstalling the app to trigger the Health permission prompt again."
            ]
        } else {
            guidanceLines = []
        }

        return HealthDebugSnapshot(
            healthDataAvailable: HKHealthStore.isHealthDataAvailable(),
            stepTypeAvailable: stepTypeAvailable,
            steps: Int(stepCount.rounded()),
            sleepHours: dailySummary.sleepHours,
            averageHeartRateBpm: averageHR,
            stepSeriesCount: series.count,
            stepSeries: series,
            permissionLines: permissionLines,
            guidanceLines: guidanceLines,
            lastSyncAt: Date()
        )
    }

    func debugHealthKitStatus() async throws -> HealthStepDebugSnapshot {
        let permissionLinesBase = [
            "HealthKit read access is validated using query results, not authorizationStatus(for:)."
        ]
        let healthDataAvailable = HKHealthStore.isHealthDataAvailable()
        let stepTypeAvailable = HKQuantityType.quantityType(forIdentifier: .stepCount) != nil

        var lastErrorMessage: String?
        var todaySteps = 0
        var stepSeries: [DailyStepCount] = []

        do {
            todaySteps = Int((try await fetchTodaySteps()).rounded())
        } catch {
            lastErrorMessage = "Today steps query failed: \(error.localizedDescription)"
            print("[HealthKit] Today steps debug failure: \(error.localizedDescription)")
        }

        do {
            stepSeries = try await fetchStepSeries(days: 7)
        } catch {
            let seriesMessage = "7-day steps query failed: \(error.localizedDescription)"
            lastErrorMessage = [lastErrorMessage, seriesMessage].compactMap { $0 }.joined(separator: " | ")
            print("[HealthKit] Step series debug failure: \(error.localizedDescription)")
        }

        let guidanceLines: [String]
        if todaySteps == 0 {
            guidanceLines = [
                "BeU could not read step data. Check Settings > Privacy & Security > Health > BeU and ensure Steps is enabled.",
                "Apple may hide Health data from apps if read permission was denied.",
                "Try deleting and reinstalling the app to trigger the Health permission prompt again."
            ]
        } else {
            guidanceLines = []
        }

        let permissionLines = permissionLinesBase + [
            "Today steps query returned \(todaySteps) steps.",
            "7-day steps query returned \(stepSeries.count) daily buckets."
        ]

        return HealthStepDebugSnapshot(
            healthDataAvailable: healthDataAvailable,
            stepTypeAvailable: stepTypeAvailable,
            todaySteps: todaySteps,
            stepSeries: stepSeries,
            permissionLines: permissionLines,
            guidanceLines: guidanceLines,
            lastSyncAt: Date(),
            lastErrorMessage: lastErrorMessage
        )
    }

    private func fetchDailySummary(for date: Date, userId: String) async throws -> HealthSummary {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.healthDataUnavailable
        }
        let queryEnd = min(end, Date())
        print("Building daily summary for \(Self.isoDateFormatter.string(from: start))")
        print("Querying from: \(start) to: \(queryEnd)")

        // Daily aggregation happens here: raw HealthKit samples are converted
        // into a normalized, backend-friendly summary for one calendar day.
        async let steps = (try? await fetchSteps(for: start)) ?? 0
        async let activeEnergy = (try? await sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: queryEnd, label: "active energy")) ?? 0
        async let basalEnergy = try? await sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), start: start, end: queryEnd, label: "basal energy")
        async let workouts = (try? await workoutSummary(start: start, end: queryEnd)) ?? (count: 0, minutes: 0, energyKcal: 0)
        async let sleepHours = (try? await sleepSummary(start: start, end: queryEnd)) ?? 0
        async let restingHeartRate = try? await averageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: queryEnd, label: "resting heart rate")
        async let hrv = try? await averageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: queryEnd, label: "hrv")
        async let weight = try? await latestBodyMetric(.bodyMass, unit: .gramUnit(with: .kilo), upTo: queryEnd, label: "weight")
        async let height = try? await latestBodyMetric(.height, unit: .meterUnit(with: .centi), upTo: queryEnd, label: "height")

        let activeEnergyKcal = await activeEnergy
        let basalEnergyKcal = await basalEnergy
        let workoutData = await workouts
        let estimatedTotalBurnKcal = (basalEnergyKcal ?? 0) + activeEnergyKcal
        return HealthSummary(
            userId: userId,
            date: Self.isoDateFormatter.string(from: start),
            steps: Int((await steps).rounded()),
            activeEnergyKcal: activeEnergyKcal,
            basalEnergyKcal: basalEnergyKcal,
            workoutCount: workoutData.count,
            workoutMinutes: workoutData.minutes,
            workoutEnergyKcal: workoutData.energyKcal,
            totalEnergyBurnedKcal: basalEnergyKcal.map { $0 + activeEnergyKcal },
            estimatedTotalBurnKcal: estimatedTotalBurnKcal,
            sleepHours: await sleepHours,
            restingHeartRateBpm: await restingHeartRate ?? nil,
            hrvMs: await hrv ?? nil,
            weightKg: await weight ?? nil,
            heightCm: await height ?? nil
        )
    }

    private func fetchRollingSummaries(userId: String, days: Int, startOffset: Int = 0) async throws -> [HealthSummary] {
        let today = calendar.startOfDay(for: Date())
        return try await withThrowingTaskGroup(of: HealthSummary.self) { group in
            for offset in startOffset..<(startOffset + days) {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                group.addTask {
                    try await self.fetchDailySummary(for: date, userId: userId)
                }
            }

            var results: [HealthSummary] = []
            for try await summary in group {
                results.append(summary)
            }

            return results.sorted(by: { $0.date < $1.date })
        }
    }

    private func sumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        label: String
    ) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.unsupportedType
        }

        print("Fetching \(label)...")
        print("Querying from: \(start) to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    print("\(label.capitalized) query error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                if let result {
                    print("\(label.capitalized) result: \(result)")
                } else {
                    print("\(label.capitalized) result is nil")
                }
                if value == 0 {
                    print("No data found for \(label)")
                }
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func averageQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        label: String
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.unsupportedType
        }

        print("Fetching \(label)...")
        print("Querying from: \(start) to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error {
                    print("\(label.capitalized) query error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                if let result {
                    print("\(label.capitalized) result: \(result)")
                } else {
                    print("\(label.capitalized) result is nil")
                }

                let value = result?.averageQuantity()?.doubleValue(for: unit)
                if value == nil {
                    print("No data found for \(label)")
                }
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func latestBodyMetric(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        upTo end: Date,
        label: String
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.unsupportedType
        }

        print("Fetching \(label)...")
        print("Querying up to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: end, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error {
                    print("\(label.capitalized) query error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                let sample = results?.first as? HKQuantitySample
                if sample == nil {
                    print("No data found for \(label)")
                }
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }

            store.execute(query)
        }
    }

    private func workoutSummary(start: Date, end: Date) async throws -> (count: Int, minutes: Double, energyKcal: Double) {
        print("Fetching workouts...")
        print("Querying from: \(start) to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error {
                    print("Workouts query error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (results as? [HKWorkout]) ?? []
                print("Workouts result count: \(workouts.count)")
                if workouts.isEmpty {
                    print("No data found for workouts")
                }
                let minutes = workouts.reduce(0) { $0 + $1.duration / 60.0 }
                let energy = workouts.reduce(0) { partial, workout in
                    partial + (workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
                }

                continuation.resume(returning: (workouts.count, minutes, energy))
            }

            store.execute(query)
        }
    }

    private func sleepSummary(start: Date, end: Date) async throws -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.unsupportedType
        }

        print("Fetching sleep...")
        print("Querying from: \(start) to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error {
                    print("Sleep query error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                let samples = (results as? [HKCategorySample]) ?? []
                let sleepingValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let totalSeconds = samples
                    .filter { sleepingValues.contains($0.value) }
                    .reduce(0.0) { partial, sample in
                        let clippedStart = max(sample.startDate, start)
                        let clippedEnd = min(sample.endDate, end)
                        return partial + max(0, clippedEnd.timeIntervalSince(clippedStart))
                    }

                if totalSeconds == 0 {
                    print("No data found for sleep")
                } else {
                    print("Sleep hours result: \(totalSeconds / 3600.0)")
                }
                continuation.resume(returning: totalSeconds / 3600.0)
            }

            store.execute(query)
        }
    }

    private func requiredReadTypes() -> Set<HKObjectType> {
        // HealthKit permissions are grouped here so the app can present
        // a single, clear read-only consent flow for the MVP dashboard.
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .bodyMass,
            .height
        ]

        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis
        ]

        return Set(
            quantityTypes.compactMap(HKObjectType.quantityType) +
            categoryTypes.compactMap(HKObjectType.categoryType) +
            [HKObjectType.workoutType()]
        )
    }

    private func logAuthorizationStatuses(for objectTypes: Set<HKObjectType>) {
        let sortedTypes = objectTypes.sorted(by: { $0.identifier < $1.identifier })
        for type in sortedTypes {
            let status = store.authorizationStatus(for: type)
            print("[HealthKit] Authorization status for \(type.identifier): \(status.rawValue)")
        }
        print("[HealthKit] Note: authorizationStatus(for:) is not treated as proof of read access. Query results drive app behavior.")
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Daily summaries should reflect the user's local calendar day,
        // not UTC, otherwise dates can appear one day behind.
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    private static func hasMeaningfulData(_ summary: HealthSummary) -> Bool {
        summary.steps > 0 ||
        summary.activeEnergyKcal > 0 ||
        summary.workoutCount > 0 ||
        summary.workoutMinutes > 0 ||
        summary.workoutEnergyKcal > 0 ||
        summary.sleepHours > 0 ||
        summary.restingHeartRateBpm != nil ||
        summary.hrvMs != nil
    }

    private static func mockSummaries(userId: String, days: Int) -> [HealthSummary] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let samples: [(steps: Int, active: Double, workouts: Int, minutes: Double, workoutEnergy: Double, sleep: Double, rhr: Double, hrv: Double)] = [
            (6400, 390, 0, 0, 0, 7.2, 59, 42),
            (8200, 520, 1, 38, 250, 6.8, 58, 45),
            (7100, 430, 0, 0, 0, 6.3, 60, 40),
            (9300, 610, 1, 44, 315, 7.0, 57, 47),
            (6800, 410, 0, 0, 0, 6.6, 60, 41),
            (10200, 680, 1, 52, 360, 7.4, 56, 49),
            (7800, 540, 1, 34, 225, 6.5, 58, 44)
        ]

        let trimmed = Array(samples.suffix(days))

        return trimmed.enumerated().map { index, sample in
            let offset = trimmed.count - index - 1
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today

            return HealthSummary(
                userId: userId,
                date: isoDateFormatter.string(from: date),
                steps: sample.steps,
                activeEnergyKcal: sample.active,
                basalEnergyKcal: 1520,
                workoutCount: sample.workouts,
                workoutMinutes: sample.minutes,
                workoutEnergyKcal: sample.workoutEnergy,
                totalEnergyBurnedKcal: 1520 + sample.active,
                estimatedTotalBurnKcal: 1520 + sample.active,
                sleepHours: sample.sleep,
                restingHeartRateBpm: sample.rhr,
                hrvMs: sample.hrv,
                weightKg: 78.4,
                heightCm: 178
            )
        }
    }
}
