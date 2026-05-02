import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    private let healthLookbackDays = 30

    @Published var todaySummary: HealthSummary?
    @Published var weeklySummaries: [HealthSummary] = []
    @Published var recommendation: DietRecommendation?
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recencyMessage: String?
    @Published var privacyMessage = "BeU reads daily health summaries from Apple Health, sends only normalized daily summaries to the backend, and avoids raw sample upload."
    @Published var foodLogAdherence: FoodAdherence?
    @Published var foodLogTags: Set<String> = []
    @Published var showingFullPlan = false
    @Published var lastSyncDebugMessage: String?
    @Published var healthDebugAlertMessage: String?
    @Published var permissionDebugLines: [String] = []
    @Published var stepDebugHealthDataAvailable = false
    @Published var stepDebugStepTypeAvailable = false
    @Published var stepDebugTodaySteps: Int?
    @Published var stepDebugSeriesCount = 0
    @Published var stepDebugLastSyncAt: Date?
    @Published var stepDebugLastErrorMessage: String?
    @Published var dailyActionPlan: DailyPersonalizedActionPlan?
    @Published var weeklyActionPlan: WeeklyPersonalizedActionPlan?
    @Published var weeklyInsights: WeeklyInsightsResponse?

    let userId: String
    let defaultGoal: UserGoal = .generalWellness
    let availableFoodTags = [
        "High protein",
        "Balanced",
        "Heavy meal",
        "Low protein",
        "Ate out",
        "Skipped meal",
        "Hydrated well"
    ]

    private let healthKitManager: HealthKitManager
    private let apiClient: APIClient
    private let planService: PlanService
    private let userDefaults = UserDefaults.standard
    private let dailyActionPlanService = DailyActionPlanService()
    private var nutritionProfile: UserNutritionProfile?
    private var dailyNutritionProgress: DailyNutritionProgress?
    private var supplements: [Supplement] = []
    private var healthConditions: [HealthCondition] = []

    init(
        userId: String = "demo-user",
        healthKitManager: HealthKitManager = HealthKitManager(),
        apiClient: APIClient = APIClient(),
        planService: PlanService = PlanService()
    ) {
        self.userId = userId
        self.healthKitManager = healthKitManager
        self.apiClient = apiClient
        self.planService = planService

        #if targetEnvironment(simulator)
        self.privacyMessage = "Simulator mode is using mock health summaries for MVP testing. On a physical iPhone, the app reads Apple Health data and sends only normalized daily summaries to the backend."
        #endif

        loadTodayFoodLog()
    }

    private var activeSummary: HealthSummary? {
        guard let todaySummary, hasRenderableSignal(todaySummary) else {
            return nil
        }
        return todaySummary
    }

    var readinessCard: ReadinessCardModel {
        guard let todaySummary = activeSummary else {
            return ReadinessCardModel(
                score: nil,
                status: "Waiting",
                message: "Sync today’s activity and recovery data to see readiness.",
                contributingFactors: [
                    "No summary available yet.",
                    "Health permissions may still be syncing.",
                    "The card will update as soon as today’s data appears."
                ]
            )
        }

        return readinessEvaluation(for: todaySummary, within: weeklySummaries)
    }

    var readinessTrendSummary: ReadinessTrendSummary {
        let recentSeven = Array(weeklySummaries.suffix(7))
        let points = recentSeven.map { summary -> ReadinessTrendPoint in
            let evaluation = readinessEvaluation(for: summary, within: weeklySummaries)
            return ReadinessTrendPoint(
                date: summary.date,
                score: evaluation.score,
                status: evaluation.score == nil ? "No data" : evaluation.status,
                topReason: evaluation.contributingFactors.first ?? "No data"
            )
        }

        let scores = points.compactMap(\.score)
        let averageScore = scores.isEmpty ? nil : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
        let highestScore = scores.max()
        let lowestScore = scores.min()

        let previousFour = Array(points.prefix(4)).compactMap(\.score)
        let lastThree = Array(points.suffix(3)).compactMap(\.score)
        let previousAverage = previousFour.isEmpty ? nil : Double(previousFour.reduce(0, +)) / Double(previousFour.count)
        let lastAverage = lastThree.isEmpty ? nil : Double(lastThree.reduce(0, +)) / Double(lastThree.count)

        let trendDirection: String
        if let previousAverage, let lastAverage {
            let delta = lastAverage - previousAverage
            if delta >= 5 {
                trendDirection = "improving"
            } else if delta <= -5 {
                trendDirection = "declining"
            } else {
                trendDirection = "stable"
            }
        } else {
            trendDirection = "stable"
        }

        let summaryMessage: String
        switch trendDirection {
        case "improving":
            summaryMessage = "Your recovery trend is improving this week."
        case "declining":
            summaryMessage = "Your recovery trend is lower this week. Prioritize sleep and lighter activity."
        default:
            summaryMessage = "Your readiness has been stable this week."
        }

        return ReadinessTrendSummary(
            points: points,
            averageScore: averageScore,
            highestScore: highestScore,
            lowestScore: lowestScore,
            trendDirection: trendDirection,
            summaryMessage: summaryMessage
        )
    }

    var insightsCard: InsightsCardModel {
        if let recommendation {
            let items = Array(([recommendation.personalizationNote] + recommendation.signals).prefix(2))
            return InsightsCardModel(items: items)
        }

        if let todaySummary = activeSummary {
            var items: [String] = []
            if todaySummary.sleepHours > 0, todaySummary.sleepHours < 6.5 {
                items.append("Sleep is short today, so recovery habits should lead the plan.")
            }
            if todaySummary.workoutCount > 0 || todaySummary.workoutMinutes > 0 {
                items.append("Recent training suggests prioritizing protein and hydration.")
            }
            if todaySummary.activeEnergyKcal > 0 {
                items.append("Daily activity is synced and ready to shape your plan.")
            }
            return InsightsCardModel(items: Array(items.prefix(2)).isEmpty ? ["Refresh guidance to generate tailored insights for today."] : Array(items.prefix(2)))
        }

        return InsightsCardModel(items: ["Insights will appear after today’s summary is available."])
    }

    var dailyPlanCard: DailyPlanCardModel {
        let readiness = readinessCard
        return dailyActionPlanService.buildPlan(
            profile: nutritionProfile,
            health: activeSummary,
            readiness: readiness,
            nutrition: dailyNutritionProgress,
            supplements: supplements,
            conditions: healthConditions
        )
    }

    var consistencyCard: ConsistencyCardModel {
        let recentDates = lastNDates(count: 7)
        let logs = recentDates.map(loadFoodLog(for:))
        let weeklyScore = Int(((logs.reduce(0.0) { partial, entry in
            partial + (entry?.adherence.score ?? 0)
        } / 7.0) * 100).rounded())

        let currentStreak = calculateCurrentStreak()
        let message: String

        switch currentStreak {
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
            currentStreak: currentStreak,
            weeklyConsistencyScore: weeklyScore,
            message: message
        )
    }

    var weeklySummaryPreview: String {
        if weeklySummaries.count < 3 {
            return "Weekly report becomes more useful as more daily summaries sync."
        }
        return "Compare this week’s activity, sleep, and consistency trends in one place."
    }

    var syncDebugLines: [String] {
        var lines: [String] = []

        if let todaySummary {
            lines.append("Latest summary date: \(todaySummary.date)")

            let availableSignals = [
                todaySummary.steps > 0 ? "steps" : nil,
                todaySummary.activeEnergyKcal > 0 ? "active energy" : nil,
                todaySummary.workoutCount > 0 || todaySummary.workoutMinutes > 0 ? "workouts" : nil,
                todaySummary.sleepHours > 0 ? "sleep" : nil,
                todaySummary.restingHeartRateBpm != nil ? "resting HR" : nil,
                todaySummary.hrvMs != nil ? "HRV" : nil,
                todaySummary.weightKg != nil ? "weight" : nil,
                todaySummary.heightCm != nil ? "height" : nil
            ].compactMap { $0 }

            lines.append("Signals found: \(availableSignals.isEmpty ? "none" : availableSignals.joined(separator: ", "))")
        } else {
            lines.append("No normalized Health summary is available yet.")
        }

        lines.append("Fetched days in memory: \(weeklySummaries.count)")

        lines.append(contentsOf: permissionDebugLines)

        if let recencyMessage {
            lines.append(recencyMessage)
        }

        if let lastSyncDebugMessage {
            lines.append(lastSyncDebugMessage)
        } else if let errorMessage {
            lines.append("Last error: \(errorMessage)")
        }

        return lines
    }

    var stepDebugSummaryLines: [String] {
        var lines = [
            "Device health data available: \(stepDebugHealthDataAvailable ? "true" : "false")",
            "Step type available: \(stepDebugStepTypeAvailable ? "true" : "false")",
            "Today step query result: \(stepDebugTodaySteps.map(String.init) ?? "Not run")",
            "7-day query result count: \(stepDebugSeriesCount)"
        ]

        if let stepDebugLastSyncAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            lines.append("Last sync timestamp: \(formatter.string(from: stepDebugLastSyncAt))")
        } else {
            lines.append("Last sync timestamp: Not run")
        }

        if let stepDebugLastErrorMessage, !stepDebugLastErrorMessage.isEmpty {
            lines.append("Last error message: \(stepDebugLastErrorMessage)")
        } else {
            lines.append("Last error message: None")
        }

        return lines
    }

    func requestPermissionsAndLoad() async {
        isLoading = true
        errorMessage = nil
        lastSyncDebugMessage = "Requesting Health access..."
        do {
            try await healthKitManager.requestAuthorization()
            isAuthorized = true
            lastSyncDebugMessage = "Health access granted. Loading summaries..."
            try await refreshData()
        } catch {
            errorMessage = friendlyMessage(for: error)
            lastSyncDebugMessage = "Health sync failed: \(friendlyMessage(for: error))"
        }
        isLoading = false
    }

    func refreshData() async throws {
        isLoading = true
        defer { isLoading = false }

        let summaries = try await healthKitManager.fetchSummaries(userId: userId, days: healthLookbackDays)
        await MainActor.run {
            weeklySummaries = summaries
            todaySummary = summaries.last(where: hasRenderableSignal) ?? summaries.last
            recommendation = nil
            recencyMessage = buildRecencyMessage(from: todaySummary?.date)
            loadTodayFoodLog()
        }

        if summaries.isEmpty {
            errorMessage = noHealthDataMessage
            lastSyncDebugMessage = "Health fetch completed, but no summaries were returned."
        } else if summaries.contains(where: hasRenderableSignal) {
            errorMessage = nil
            lastSyncDebugMessage = "Health fetch completed. Showing the most recent available summary with readable Apple Health signals."
        } else {
            errorMessage = noHealthDataMessage
            lastSyncDebugMessage = "Health fetch completed, but none of the requested Apple Health signals had readable samples in the current lookback."
        }

        await refreshEnginePlans()
    }

    func runHealthDebugFetch() async {
        isLoading = true
        errorMessage = nil
        lastSyncDebugMessage = "Running manual HealthKit debug fetch..."
        do {
            try await healthKitManager.requestAuthorization()
            let snapshot = try await healthKitManager.debugFetchSnapshot(userId: userId)
            try await refreshData()

            let hrText = snapshot.averageHeartRateBpm.map { String(format: "%.0f", $0) } ?? "N/A"
            permissionDebugLines = snapshot.permissionLines
            healthDebugAlertMessage = (
                [
                    "Health data available: \(snapshot.healthDataAvailable ? "Yes" : "No")",
                    "Steps: \(snapshot.steps)",
                    "Sleep: \(String(format: "%.1f", snapshot.sleepHours))h",
                    "HR: \(hrText)"
                ] + snapshot.permissionLines
            ).joined(separator: "\n")
            lastSyncDebugMessage = "Manual debug fetch completed."
        } catch {
            let message = friendlyMessage(for: error)
            errorMessage = message
            lastSyncDebugMessage = "Manual debug fetch failed: \(message)"
            healthDebugAlertMessage = message
        }
        isLoading = false
    }

    func testStepSync() async {
        isLoading = true
        errorMessage = nil
        lastSyncDebugMessage = "Running step sync test..."

        do {
            try await healthKitManager.requestAuthorization()
            let snapshot = try await healthKitManager.debugHealthKitStatus()

            stepDebugHealthDataAvailable = snapshot.healthDataAvailable
            stepDebugStepTypeAvailable = snapshot.stepTypeAvailable
            stepDebugTodaySteps = snapshot.todaySteps
            stepDebugSeriesCount = snapshot.stepSeries.count
            stepDebugLastSyncAt = snapshot.lastSyncAt
            stepDebugLastErrorMessage = snapshot.lastErrorMessage
            permissionDebugLines = snapshot.permissionLines

            if snapshot.todaySteps == 0 {
                errorMessage = snapshot.guidanceLines.first ?? noHealthDataMessage
                lastSyncDebugMessage = snapshot.guidanceLines.joined(separator: " ")
            } else {
                errorMessage = nil
                lastSyncDebugMessage = "Fetched \(snapshot.todaySteps) steps and \(snapshot.stepSeries.count) daily buckets."
            }

            healthDebugAlertMessage = (
                [
                    "Today steps: \(snapshot.todaySteps)",
                    "7-day buckets: \(snapshot.stepSeries.count)"
                ] + snapshot.guidanceLines
            ).joined(separator: "\n")

            try await refreshData()
        } catch {
            let message = friendlyMessage(for: error)
            stepDebugLastErrorMessage = message
            stepDebugLastSyncAt = Date()
            lastSyncDebugMessage = "Step sync failed: \(message)"
            errorMessage = message
            healthDebugAlertMessage = "Steps: 0\n7-day buckets: 0\n\(message)"
        }

        isLoading = false
    }

    func saveGoal() async throws {
        _ = try await apiClient.save(goal: UserGoalPayload(userId: userId, goal: defaultGoal, notes: nil))
    }

    func updatePersonalizationContext(
        profile: UserNutritionProfile?,
        progress: DailyNutritionProgress?,
        supplements: [Supplement],
        healthConditions: [HealthCondition]
    ) {
        nutritionProfile = profile
        dailyNutritionProgress = progress
        self.supplements = supplements
        self.healthConditions = healthConditions.filter(\.isActive)
        objectWillChange.send()
        Task {
            await refreshEnginePlans()
        }
    }

    func logWater(_ litres: Double) async {
        do {
            let response = try await planService.logWater(userId: userId, litres: litres)
            dailyActionPlan = response.plan
            await refreshEnginePlans()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func generateRecommendation() async {
        guard let todaySummary else {
            errorMessage = "No daily summary is available yet."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await saveGoal()

            _ = try await apiClient.save(summary: todaySummary)

            for summary in weeklySummaries.dropLast() {
                do {
                    _ = try await apiClient.save(summary: summary)
                } catch {
                }
            }

            recommendation = try await apiClient.generateRecommendation(userId: userId, date: todaySummary.date)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isLoading = false
    }

    func setFoodLogAdherence(_ adherence: FoodAdherence) {
        foodLogAdherence = adherence
        if adherence == .no {
            foodLogTags = []
        }
        persistTodayFoodLog()
    }

    func toggleFoodTag(_ tag: String) {
        if foodLogTags.contains(tag) {
            foodLogTags.remove(tag)
        } else {
            foodLogTags.insert(tag)
        }
        persistTodayFoodLog()
    }

    private func friendlyMessage(for error: Error) -> String {
        if let healthKitError = error as? HealthKitError {
            return healthKitError.localizedDescription
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("No data available for the specified predicate") {
            return noHealthDataMessage
        }

        return message
    }

    private var noHealthDataMessage: String {
        "No health data available yet. Open Apple Health and ensure data is being recorded."
    }

    private func buildRecencyMessage(from latestDate: String?) -> String? {
        guard let latestDate else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: latestDate) else { return nil }

        let dayDifference = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0

        if dayDifference <= 0 {
            return nil
        }

        return "Showing the most recent available Apple Health data from \(latestDate) because no newer summary was found."
    }

    private func hasRenderableSignal(_ summary: HealthSummary) -> Bool {
        summary.steps > 0 ||
        summary.activeEnergyKcal > 0 ||
        summary.workoutCount > 0 ||
        summary.workoutMinutes > 0 ||
        summary.workoutEnergyKcal > 0 ||
        summary.sleepHours > 0 ||
        summary.restingHeartRateBpm != nil ||
        summary.hrvMs != nil
    }

    private func readinessEvaluation(for summary: HealthSummary, within allSummaries: [HealthSummary]) -> ReadinessCardModel {
        let recent = allSummaries.filter { $0.date != summary.date && hasRenderableSignal($0) }
        let avgSleep = average(recent.map(\.sleepHours).filter { $0 > 0 }) ?? max(summary.sleepHours, 7)
        let avgHRV = average(recent.compactMap(\.hrvMs).filter { $0 > 0 })
        let avgRHR = average(recent.compactMap(\.restingHeartRateBpm).filter { $0 > 0 })
        let avgActive = average(recent.map(\.activeEnergyKcal).filter { $0 > 0 }) ?? max(summary.activeEnergyKcal, 1)
        let avgSteps = average(recent.map { Double($0.steps) }.filter { $0 > 0 })
        let yesterdayActive = recent.last?.activeEnergyKcal ?? summary.activeEnergyKcal

        var weightedScores: [(weight: Double, score: Double)] = []
        var factors: [String] = []

        if avgSleep > 0, summary.sleepHours > 0 {
            let score = min((summary.sleepHours / avgSleep) * 30, 30)
            weightedScores.append((30, score))
            factors.append(summary.sleepHours < avgSleep ? "Sleep was below your recent average." : "Sleep was in line with your recent average.")
        }

        if let avgHRV, avgHRV > 0, let hrv = summary.hrvMs, hrv > 0 {
            let score = min((hrv / avgHRV) * 25, 25)
            weightedScores.append((25, score))
            factors.append(hrv < avgHRV ? "HRV is lower than your recent baseline." : "HRV is holding above your recent baseline.")
        }

        if let avgRHR, avgRHR > 0, let rhr = summary.restingHeartRateBpm, rhr > 0 {
            let score = min((avgRHR / rhr) * 20, 20)
            weightedScores.append((20, score))
            factors.append(rhr > avgRHR ? "Resting heart rate is elevated versus your recent average." : "Resting heart rate is steady for you.")
        }

        if avgActive > 0 {
            let deviation = abs(yesterdayActive - avgActive) / avgActive
            let score = max(0, (1 - deviation) * 25)
            weightedScores.append((25, score))
            factors.append(deviation > 0.35 ? "Yesterday’s activity load was meaningfully different from normal." : "Activity load is close to your recent pattern.")
        }

        if let avgSteps, avgSteps > 0, summary.steps > 0 {
            let stepScore = min((Double(summary.steps) / avgSteps) * 20, 20)
            weightedScores.append((20, stepScore))
            factors.append(Double(summary.steps) < avgSteps ? "Step volume is below your recent pattern so readiness is being held back." : "Step volume is in line with your recent pattern.")
        }

        let totalWeight = weightedScores.reduce(0) { $0 + $1.weight }
        let totalScore = weightedScores.reduce(0) { $0 + $1.score }
        let normalizedScore: Int?
        if totalWeight > 0 {
            let computed = Int(((totalScore / totalWeight) * 100).rounded())
            normalizedScore = max(10, min(100, computed))
        } else if summary.steps > 0 || summary.activeEnergyKcal > 0 {
            normalizedScore = 55
            factors.append("Using activity-only signals while more recovery data becomes available.")
        } else {
            normalizedScore = nil
        }

        let status: String
        let message: String

        switch normalizedScore ?? 0 {
        case 75...100:
            status = "High"
            message = "Good recovery. You can follow your normal plan today."
        case 50...74:
            status = "Moderate"
            message = "Decent recovery. Keep activity balanced today."
        default:
            status = "Low"
            message = "Recovery looks low. Prioritize sleep, hydration, and lighter activity."
        }

        let uniqueFactors = factors.reduce(into: [String]()) { partial, factor in
            if !partial.contains(factor) {
                partial.append(factor)
            }
        }

        let fallbackFactors = factors.isEmpty ? [
            "Limited recovery signals available today.",
            "The app is using the available sleep and activity data.",
            "More Health data will improve personalization."
        ] : Array(uniqueFactors.prefix(3))

        return ReadinessCardModel(
            score: normalizedScore,
            status: normalizedScore == nil ? "No data" : status,
            message: normalizedScore == nil ? "Limited data available. Use a lighter, balanced day." : message,
            contributingFactors: fallbackFactors
        )
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func refreshEnginePlans() async {
        do {
            async let dailyPlanTask = planService.fetchTodayPlan(userId: userId)
            async let weeklyPlanTask = planService.fetchWeeklyPlan(userId: userId)
            async let insightsTask = planService.fetchWeeklyInsights(userId: userId)

            let plan = try await dailyPlanTask
            let weeklyPlan = try await weeklyPlanTask
            let insights = try await insightsTask

            dailyActionPlan = plan
            weeklyActionPlan = weeklyPlan
            weeklyInsights = insights
        } catch {
            let fallbackDaily = planService.fallbackDailyPlan(
                userId: userId,
                readiness: readinessCard,
                card: dailyPlanCard,
                progress: dailyNutritionProgress,
                summary: activeSummary
            )
            dailyActionPlan = fallbackDaily
            weeklyActionPlan = planService.fallbackWeeklyPlan(
                from: fallbackDaily,
                trend: readinessTrendSummary
            )
            weeklyInsights = planService.fallbackWeeklyInsights(
                from: readinessTrendSummary,
                consistency: consistencyCard
            )
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

    private func lastNDates(count: Int) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"

        return (0..<count).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: Date()).map(formatter.string(from:))
        }
    }

    private func foodLogKey(for date: String) -> String {
        "foodLog_\(date)"
    }

    private func loadTodayFoodLog() {
        let entry = loadFoodLog(for: todayDateString())
        foodLogAdherence = entry?.adherence
        foodLogTags = Set(entry?.tags ?? [])
    }

    private func loadFoodLog(for date: String) -> FoodLogEntry? {
        guard let data = userDefaults.data(forKey: foodLogKey(for: date)),
              let entry = try? JSONDecoder().decode(FoodLogEntry.self, from: data) else {
            return nil
        }
        return entry
    }

    private func persistTodayFoodLog() {
        guard let adherence = foodLogAdherence else { return }
        let entry = FoodLogEntry(date: todayDateString(), adherence: adherence, tags: Array(foodLogTags).sorted())
        if let data = try? JSONEncoder().encode(entry) {
            userDefaults.set(data, forKey: foodLogKey(for: entry.date))
        }
        objectWillChange.send()
    }

    private func calculateCurrentStreak() -> Int {
        let dates = lastNDates(count: 30)
        var streak = 0

        for (index, date) in dates.enumerated() {
            let entry = loadFoodLog(for: date)
            if index == 0, entry == nil {
                continue
            }

            guard let adherence = entry?.adherence else {
                break
            }

            switch adherence {
            case .yes, .partial:
                streak += 1
            case .no:
                return streak
            }
        }

        return streak
    }
}
