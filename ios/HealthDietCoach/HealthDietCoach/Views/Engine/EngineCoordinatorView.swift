import SwiftUI
import UIKit

@MainActor
final class EngineCoordinatorModel: ObservableObject {
    enum BackendStatus {
        case unknown
        case waking
        case connected
        case unavailable

        var label: String {
            switch self {
            case .unknown:
                return "Checking"
            case .waking:
                return "Waking up"
            case .connected:
                return "Connected"
            case .unavailable:
                return "Backend unavailable"
            }
        }
    }

    enum Phase {
        case onboard
        case app
        case changingGoal
    }

    @Published var phase: Phase
    @Published var onboardingMode: BeUOnboardingMode
    @Published var selectedTab: BeUAppTab = .home
    @Published var baseline: Baseline?
    @Published var goalConfig: GoalConfig?
    @Published var dailyPlan: DailyPlan?
    @Published var nudges: [DailyNudge] = []
    @Published var weeklyInsights: WeeklyInsights?
    @Published var journeySnapshot: JourneySnapshot?
    @Published var selectedJourneyChallenge: JourneyChallenge
    @Published var intake: DailyIntake = .init(kcal: 0, protein: 0, carbs: 0, fat: 0, waterLitres: 0, steps: 0, mealsLoggedToday: 0, lastMealType: nil)
    @Published var mealsToday: [MealLog] = []
    @Published var mealsThisWeek: [MealLog] = []
    @Published var supplementIntakeLogs: [SupplementIntakeLog] = []
    @Published var showingMealSheet = false
    @Published var mealBeingEdited: MealLog?
    @Published var isLoading = false
    @Published var deletingMealId: String?
    @Published var errorMessage: String?
    @Published var transientMessage: String?
    @Published var backendStatus: BackendStatus = .unknown
    @Published var nextBestMealResult: NextBestMealResult?
    @Published var savedMealsForLater: [SavedMealForLater] = []
    @Published var weeklyReview: WeeklyReview?
    @Published var weeklyFocusChips: [String] = []
    @Published var dailyDelta: DailyDelta?
    @Published var showingWeeklyReview = false
    @Published var logMealPrefill: NextBestMealSuggestion?

    let onboardingStore: OnboardingStore
    let goalStore: GoalStore
    let waterStore: WaterProgressStore
    let healthGateway: HealthKitGateway

    private let planService: PlanService
    private let nudgeService: NudgeService
    private let insightsService: InsightsService
    private let journeyService: JourneyService
    private let mealLogService: MealLogService
    private let supplementIntakeLogRepository: SupplementIntakeLogRepository
    private let apiClient: APIClient
    private let nextBestMealService: NextBestMealService
    private let weeklyReviewService: WeeklyReviewService
    private let dailyDeltaService: DailyDeltaService
    private let adaptiveCoachFeatureStore: AdaptiveCoachFeatureStore
    private let userId = "local-user"
    private var lastBackendWarmupAt: Date?

    init() {
        let onboardingStore = OnboardingStore()
        let goalStore = GoalStore()
        let waterStore = WaterProgressStore()
        let healthGateway = HealthKitGateway(userId: "local-user")
        let planService = PlanService()
        let nudgeService = NudgeService()
        let insightsService = InsightsService()
        let journeyService = JourneyService()
        let mealLogService = MealLogService()
        let supplementIntakeLogRepository = SupplementIntakeLogRepository()
        let apiClient = APIClient()
        let nextBestMealService = NextBestMealService()
        let weeklyReviewService = WeeklyReviewService()
        let dailyDeltaService = DailyDeltaService()
        let adaptiveCoachFeatureStore = AdaptiveCoachFeatureStore()

        self.onboardingStore = onboardingStore
        self.goalStore = goalStore
        self.waterStore = waterStore
        self.healthGateway = healthGateway
        self.planService = planService
        self.nudgeService = nudgeService
        self.insightsService = insightsService
        self.journeyService = journeyService
        self.selectedJourneyChallenge = journeyService.selectedChallenge(for: "local-user")
        self.mealLogService = mealLogService
        self.supplementIntakeLogRepository = supplementIntakeLogRepository
        self.apiClient = apiClient
        self.nextBestMealService = nextBestMealService
        self.weeklyReviewService = weeklyReviewService
        self.dailyDeltaService = dailyDeltaService
        self.adaptiveCoachFeatureStore = adaptiveCoachFeatureStore
        self.baseline = onboardingStore.baseline
        self.goalConfig = goalStore.goalConfig
        self.savedMealsForLater = adaptiveCoachFeatureStore.savedMeals(userId: "local-user")
        self.weeklyFocusChips = adaptiveCoachFeatureStore.weeklyFocus(userId: "local-user")
        self.onboardingMode = onboardingStore.baseline == nil ? .firstRun : .reviewBaseline
        if onboardingStore.baseline == nil {
            self.phase = .onboard
        } else if goalStore.goalConfig == nil {
            self.phase = .changingGoal
        } else {
            self.phase = .app
        }
        Task { await warmUpBackendIfNeeded(force: true) }
        Task { await refreshAll() }
    }

    var currentBaseline: Baseline {
        baseline ?? Baseline.prototype
    }

    var currentGoalConfig: GoalConfig {
        goalConfig ?? GoalConfig(goal: .fatLoss, targetWeightKg: 66, timeline: .threeMonths, customYears: 2)
    }

    var currentSignals: HealthSignals {
        healthGateway.currentSignals
    }

    var readiness: Readiness {
        healthGateway.readiness
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: Date())
    }

    var greetingName: String {
        let trimmed = currentBaseline.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 ? trimmed : "there"
    }

    var planTargetCaloriesText: String {
        dailyPlan.map { "\($0.kcalTarget)" } ?? "—"
    }

    var planTargetProteinText: String {
        dailyPlan.map { "\($0.proteinTarget)g" } ?? "—"
    }

    var formattedWaterValueText: String {
        if intake.waterLitres < 1 {
            return String(format: "%.2f", intake.waterLitres)
        }
        return String(format: "%.1f", intake.waterLitres)
    }

    var goalLabel: String {
        GoalPresets[currentGoalConfig.goal]?.label ?? currentGoalConfig.goal.title
    }

    var selectedDate: String {
        Date().localYYYYMMDD
    }

    var availableJourneyChallenges: [JourneyChallenge] {
        journeyService.challenges
    }

    var currentNudges: [DailyNudge] {
        nudges
    }

    var healthContextNote: String? {
        dailyPlan?.healthContextNote
    }

    var weeklyReadinessScores: [Int] {
        let scores = healthGateway.weeklyReadiness
        return scores.isEmpty ? [61, 63, 59, 66, 67, 65, 64] : scores
    }

    var weeklyTargetProgress: [(String, String, String, Double, Color)] {
        guard let dailyPlan else {
            return []
        }
        let intakeHistory = intakeHistoryForLastWeek()
        let averageCalories = average(of: intakeHistory.map(\.kcal))
        let averageProtein = average(of: intakeHistory.map(\.protein))
        let averageWater = Double(average(of: intakeHistory.map { Int(($0.waterLitres * 10).rounded()) })) / 10.0
        return [
            ("Calories", "\(averageCalories)", "\(dailyPlan.kcalTarget)", min(Double(averageCalories) / Double(max(dailyPlan.kcalTarget, 1)), 1), BeUTheme.accent),
            ("Protein", "\(averageProtein)g", "\(dailyPlan.proteinTarget)g", min(Double(averageProtein) / Double(max(dailyPlan.proteinTarget, 1)), 1), BeUTheme.warn),
            ("Water", String(format: "%.1f L", averageWater), String(format: "%.1f L", dailyPlan.waterLitresTarget), min(averageWater / max(dailyPlan.waterLitresTarget, 0.1), 1), BeUTheme.ok),
        ]
    }

    func refreshAll() async {
        isLoading = true
        errorMessage = nil
        waterStore.loadToday()
        await warmUpBackendIfNeeded()
        await healthGateway.refresh()
        loadSupplementIntakeLogs()
        loadMeals()
        rebuildPlan()
        syncJourney()
        isLoading = false
    }

    func warmUpBackendIfNeeded(force: Bool = false) async {
        if force == false,
           let lastBackendWarmupAt,
           Date().timeIntervalSince(lastBackendWarmupAt) < 60 {
            return
        }

        lastBackendWarmupAt = Date()
        backendStatus = .waking

        do {
            _ = try await apiClient.fetchHealthStatus()
            backendStatus = .connected
        } catch {
            backendStatus = .unavailable
        }
    }

    func saveBaseline(_ baseline: Baseline) {
        onboardingStore.save(baseline)
        self.baseline = baseline
        onboardingMode = .reviewBaseline
        if goalConfig == nil {
            phase = .changingGoal
        } else {
            phase = .app
        }
        rebuildPlan()
    }

    func saveGoal(_ goalConfig: GoalConfig) {
        goalStore.save(goalConfig)
        self.goalConfig = goalConfig
        phase = .app
        selectedTab = .home
        rebuildPlan()
    }

    func reopenBaseline() {
        onboardingMode = .reviewBaseline
        phase = .onboard
    }

    func changeGoal() {
        phase = .changingGoal
    }

    @discardableResult
    func addWater() -> Bool {
        guard waterStore.add100Millilitres() else { return false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        loadMeals()
        rebuildPlan()
        if let target = dailyPlan?.waterLitresTarget {
            let litres = waterStore.litresToday
            UIAccessibility.post(
                notification: .announcement,
                argument: "Logged 100 millilitres. \(formattedWaterForAccessibility(litres)) of \(String(format: "%.1f", target)) litres."
            )
        }
        return true
    }

    func openLogMeal() {
        mealBeingEdited = nil
        logMealPrefill = nil
        showingMealSheet = true
    }

    func openLogMeal(prefill suggestion: NextBestMealSuggestion) {
        mealBeingEdited = nil
        logMealPrefill = suggestion
        showingMealSheet = true
    }

    func editMeal(_ meal: MealLog) {
        mealBeingEdited = meal
        logMealPrefill = nil
        showingMealSheet = true
    }

    func didSaveMeal(_ meal: MealLog) {
        mealLogService.createMealLog(meal)
        mealBeingEdited = nil
        logMealPrefill = nil
        showingMealSheet = false
        loadMeals()
        rebuildPlan()
    }

    func didUpdateMeal(_ meal: MealLog) {
        mealLogService.updateMealLog(id: meal.id, updatedMealLog: meal)
        mealBeingEdited = nil
        logMealPrefill = nil
        loadMeals()
        rebuildPlan()
    }

    @discardableResult
    func didDeleteMeal(_ meal: MealLog) async -> Bool {
        let mealId = meal.id
        guard deletingMealId == nil else { return false }

        await MainActor.run {
            deletingMealId = mealId
        }

        print("[MealDelete] Delete requested:", mealId)

        let deleted = mealLogService.deleteMealLog(id: mealId, userId: meal.userId)

        await MainActor.run {
            if mealBeingEdited?.id == mealId {
                mealBeingEdited = nil
            }
            loadMeals()
            rebuildPlan()
            if deleted {
                transientMessage = "Meal deleted"
            }
            deletingMealId = nil
        }

        if deleted {
            print("[MealDelete] Deleted:", mealId)
        }
        print("[MealDelete] Meals remaining:", mealsToday.count)
        scheduleTransientMessageClear()
        return true
    }

    func mealDeleteFailed(_ error: Error) {
        print("[MealDelete] Failed:", error.localizedDescription)
        errorMessage = "Could not delete meal. Please try again."
        deletingMealId = nil
    }

    func mealDeleteInProgress(for mealId: String) -> Bool {
        deletingMealId == mealId
    }

    func clearMealEditingState(for mealId: String) {
        if mealBeingEdited?.id == mealId {
            mealBeingEdited = nil
        }
    }

    func markSupplementTaken(_ supplement: Supplement) {
        let date = selectedDate
        _ = supplementIntakeLogRepository.markTaken(userId: userId, supplementId: supplement.id, date: date)
        loadSupplementIntakeLogs()
        rebuildPlan()
    }

    func undoSupplementTaken(_ supplement: Supplement) {
        supplementIntakeLogRepository.undoTaken(userId: userId, supplementId: supplement.id, date: selectedDate)
        loadSupplementIntakeLogs()
        rebuildPlan()
    }

    func selectJourneyChallenge(_ challenge: JourneyChallenge) {
        guard selectedJourneyChallenge.id != challenge.id else { return }
        journeyService.selectChallenge(challenge.id, for: userId)
        selectedJourneyChallenge = challenge
        syncJourney()
    }

    func saveMealForLater(_ suggestion: NextBestMealSuggestion) {
        savedMealsForLater = adaptiveCoachFeatureStore.saveMeal(suggestion, userId: userId)
        transientMessage = "Saved for later"
        scheduleTransientMessageClear()
    }

    func isMealSavedForLater(_ suggestion: NextBestMealSuggestion) -> Bool {
        savedMealsForLater.contains {
            $0.id == suggestion.id || $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame
        }
    }

    func applyWeeklyFocus(_ chips: [String]) {
        adaptiveCoachFeatureStore.saveWeeklyFocus(chips, userId: userId)
        weeklyFocusChips = adaptiveCoachFeatureStore.weeklyFocus(userId: userId)
        showingWeeklyReview = false
        transientMessage = "Weekly focus saved"
        scheduleTransientMessageClear()
    }

    func isSupplementTaken(_ supplement: Supplement) -> Bool {
        supplementIntakeLogs.contains {
            $0.supplementId == supplement.id &&
            $0.date == selectedDate &&
            $0.status == "taken"
        }
    }

    private func rebuildPlan() {
        guard let baseline else { return }
        let plan = planService.buildPlan(
            userId: userId,
            baseline: baseline,
            goalConfig: currentGoalConfig,
            intake: intake,
            readiness: readiness,
            signals: currentSignals,
            summary: healthGateway.todaySummary,
            recentSummaries: healthGateway.recentSummaries
        )
        dailyPlan = plan
        nudges = nudgeService.buildNudges(plan: plan, intake: intake)
        weeklyInsights = insightsService.buildWeeklyInsights(
            readinessScores: weeklyReadinessScores,
            intakeHistory: intakeHistoryForLastWeek(),
            plan: plan,
            summaries: healthGateway.recentSummaries
        )
        syncJourney()
        recomputeAdaptiveCoachFeatures(plan: plan)
    }

    private func loadMeals() {
        let today = selectedDate
        mealsToday = mealLogService.mealLogs(for: userId, date: today)
        mealsThisWeek = mealLogService.mealLogs(for: userId)
        intake = DailyIntake(
            kcal: mealsToday.reduce(0) { $0 + $1.totalCalories },
            protein: Int(mealsToday.reduce(0) { $0 + $1.totalProteinGrams }.rounded()),
            carbs: Int(mealsToday.reduce(0) { $0 + $1.totalCarbsGrams }.rounded()),
            fat: Int(mealsToday.reduce(0) { $0 + $1.totalFatGrams }.rounded()),
            waterLitres: waterStore.litresToday,
            steps: healthGateway.currentSteps,
            mealsLoggedToday: mealsToday.count,
            lastMealType: mealsToday.sorted(by: { $0.createdAt < $1.createdAt }).last?.mealType
        )
    }

    private func loadSupplementIntakeLogs() {
        supplementIntakeLogs = supplementIntakeLogRepository.getLogs(userId: userId, date: selectedDate)
    }

    private func syncJourney() {
        selectedJourneyChallenge = journeyService.selectedChallenge(for: userId)
        journeySnapshot = journeyService.syncJourneyProgress(
            userId: userId,
            challengeID: selectedJourneyChallenge.id,
            summaries: healthGateway.recentSummaries,
            todaySummary: healthGateway.todaySummary,
            heightCm: baseline?.heightCm,
            dailyStepGoal: dailyPlan?.cardioStepsTarget ?? 7_500
        )
    }

    private func recomputeAdaptiveCoachFeatures(plan: DailyPlan) {
        let conditions = currentBaseline.medical
            .filter { $0 != .none && $0 != .preferNotToSay }
            .map(\.title)

        let nextMealContext = NextBestMealContext(
            calorieTarget: plan.kcalTarget,
            proteinTargetGrams: Double(plan.proteinTarget),
            caloriesConsumed: intake.kcal,
            proteinConsumedGrams: Double(intake.protein),
            mealsLoggedToday: mealsToday,
            currentHour: Calendar.current.component(.hour, from: Date()),
            goalType: currentGoalConfig.goal.rawValue,
            readinessStatus: readiness.status.rawValue,
            dietPreference: baseline?.dietPreference.apiValue,
            healthConditions: conditions
        )
        nextBestMealResult = nextBestMealService.generateNextBestMeal(context: nextMealContext)

        let reviewSnapshots = weekSnapshots(plan: plan)
        weeklyReview = weeklyReviewService.generateWeeklyReview(
            context: WeeklyReviewContext(
                goalType: currentGoalConfig.goal.rawValue,
                calorieTarget: plan.kcalTarget,
                proteinTarget: plan.proteinTarget,
                stepTarget: plan.cardioStepsTarget,
                dailySnapshots: reviewSnapshots
            )
        )

        dailyDelta = dailyDeltaService.getDailyDelta(
            context: DailyDeltaContext(
                goalType: currentGoalConfig.goal.rawValue,
                calorieTarget: plan.kcalTarget,
                proteinTarget: plan.proteinTarget,
                stepTarget: plan.cardioStepsTarget,
                today: deltaSnapshot(for: selectedDate),
                yesterday: yesterdayDeltaSnapshot(),
                averageSteps: averageStepsExcludingToday(),
                averageActiveEnergy: averageActiveEnergyExcludingToday()
            )
        )
    }

    private func intakeHistoryForLastWeek() -> [DailyIntake] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = ISODateOnlyFormatter.shared.string(from: date)
            let dayMeals = mealLogService.mealLogs(for: userId, date: key)
            return DailyIntake(
                kcal: dayMeals.reduce(0) { $0 + $1.totalCalories },
                protein: Int(dayMeals.reduce(0) { $0 + $1.totalProteinGrams }.rounded()),
                carbs: Int(dayMeals.reduce(0) { $0 + $1.totalCarbsGrams }.rounded()),
                fat: Int(dayMeals.reduce(0) { $0 + $1.totalFatGrams }.rounded()),
                waterLitres: offset == 0 ? waterStore.litresToday : 0,
                steps: healthGateway.recentSummaries.first(where: { $0.date == key })?.steps ?? 0,
                mealsLoggedToday: dayMeals.count,
                lastMealType: dayMeals.sorted(by: { $0.createdAt < $1.createdAt }).last?.mealType
            )
        }
    }

    private func weekSnapshots(plan: DailyPlan) -> [WeeklyReviewContext.DaySnapshot] {
        let calendar = Calendar.current
        let readinessByDate = readinessMapForRecentSummaries()
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let key = ISODateOnlyFormatter.shared.string(from: date)
            let meals = mealLogService.mealLogs(for: userId, date: key)
            let summary = healthGateway.recentSummaries.first(where: { $0.date == key })
            let readinessTuple = readinessByDate[key]
            return WeeklyReviewContext.DaySnapshot(
                id: key,
                date: key,
                caloriesConsumed: meals.reduce(0) { $0 + $1.totalCalories },
                proteinConsumed: meals.reduce(0) { $0 + $1.totalProteinGrams },
                steps: summary?.steps ?? (offset == 0 ? intake.steps : 0),
                readinessScore: readinessTuple?.score,
                readinessStatus: readinessTuple?.status,
                mealsLogged: meals.count,
                waterLitres: offset == 0 ? intake.waterLitres : 0
            )
        }
    }

    private func readinessMapForRecentSummaries() -> [String: (score: Int, status: String)] {
        let summaries = healthGateway.recentSummaries
        let scores = weeklyReadinessScores
        return Dictionary(uniqueKeysWithValues: summaries.enumerated().map { index, summary in
            let score = index < scores.count ? scores[index] : nil
            let status: String
            switch score ?? 0 {
            case 80...:
                status = "high"
            case 60...:
                status = "good"
            case 45...:
                status = "moderate"
            default:
                status = "low"
            }
            return (summary.date, (score ?? 0, status))
        })
    }

    private func deltaSnapshot(for date: String) -> DailyDeltaContext.Snapshot {
        let meals = mealLogService.mealLogs(for: userId, date: date)
        let summary = healthGateway.recentSummaries.first(where: { $0.date == date })
        let readinessTuple = date == selectedDate ? (readiness.score, readiness.status.rawValue) : readinessMapForRecentSummaries()[date]
        return DailyDeltaContext.Snapshot(
            caloriesConsumed: meals.reduce(0) { $0 + $1.totalCalories },
            proteinConsumed: meals.reduce(0) { $0 + $1.totalProteinGrams },
            steps: summary?.steps ?? (date == selectedDate ? intake.steps : 0),
            activeEnergyBurned: summary.map { Int($0.activeEnergyKcal.rounded()) },
            waterLitres: date == selectedDate ? intake.waterLitres : 0,
            readinessScore: readinessTuple?.0,
            readinessStatus: readinessTuple?.1,
            hasWorkout: (summary?.workoutCount ?? 0) > 0 || (summary?.workoutMinutes ?? 0) >= 20
        )
    }

    private func yesterdayDeltaSnapshot() -> DailyDeltaContext.Snapshot? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        return deltaSnapshot(for: ISODateOnlyFormatter.shared.string(from: yesterday))
    }

    private func averageStepsExcludingToday() -> Int? {
        let past = healthGateway.recentSummaries.filter { $0.date != selectedDate }.map(\.steps)
        guard past.isEmpty == false else { return nil }
        return Int((Double(past.reduce(0, +)) / Double(past.count)).rounded())
    }

    private func averageActiveEnergyExcludingToday() -> Int? {
        let past = healthGateway.recentSummaries
            .filter { $0.date != selectedDate }
            .map { Int($0.activeEnergyKcal.rounded()) }
        guard past.isEmpty == false else { return nil }
        return Int((Double(past.reduce(0, +)) / Double(past.count)).rounded())
    }

    private func average(of values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private func formattedWaterForAccessibility(_ litres: Double) -> String {
        if litres < 1 {
            return String(format: "%.2f", litres)
        }
        return String(format: "%.1f", litres)
    }

    private func scheduleTransientMessageClear() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                transientMessage = nil
            }
        }
    }
}

struct EngineCoordinatorView: View {
    @StateObject private var coordinator = EngineCoordinatorModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch coordinator.phase {
            case .onboard:
                BeUOnboardingFlowView(
                    mode: coordinator.onboardingMode,
                    initialBaseline: coordinator.currentBaseline,
                    onComplete: coordinator.saveBaseline,
                    onCancel: {
                        if coordinator.baseline != nil {
                            coordinator.phase = .app
                        }
                    }
                )
            case .changingGoal:
                BeUGoalSetupView(
                    mode: coordinator.goalConfig == nil ? .firstRun : .changeGoal,
                    baseline: coordinator.currentBaseline,
                    initialGoal: coordinator.currentGoalConfig,
                    onBack: {
                        coordinator.phase = coordinator.baseline == nil ? .onboard : .app
                    },
                    onSave: coordinator.saveGoal
                )
            case .app:
                appShell
            }
        }
    }

    private var appShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch coordinator.selectedTab {
                case .home:
                    BeUHomeTabView(coordinator: coordinator)
                case .plan:
                    BeUPlanTabView(coordinator: coordinator)
                case .journey:
                    JourneyView(
                        snapshot: coordinator.journeySnapshot,
                        challenges: coordinator.availableJourneyChallenges,
                        selectedChallenge: coordinator.selectedJourneyChallenge,
                        isHealthConnected: coordinator.healthGateway.isConnected,
                        onSelectChallenge: coordinator.selectJourneyChallenge,
                        onSyncHealth: {
                            Task { await coordinator.refreshAll() }
                        }
                    )
                case .progress:
                    BeUProgressTabView(coordinator: coordinator)
                case .me:
                    BeUMeTabView(coordinator: coordinator)
                }
            }
            .background(BeUTheme.background.ignoresSafeArea())

            LinearGradient(
                colors: [Color.clear, BeUTheme.background.opacity(0.92), BeUTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)

            BeUTabBar(selectedTab: coordinator.selectedTab, onSelect: { coordinator.selectedTab = $0 }, onOpenMeal: coordinator.openLogMeal)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
        }
        .sheet(isPresented: $coordinator.showingMealSheet) {
            BeULogMealSheet(
                userId: "local-user",
                dietPreference: coordinator.baseline?.dietPreference.apiValue ?? "indian_vegetarian",
                existingMeals: coordinator.mealsToday,
                waterLitres: coordinator.intake.waterLitres,
                waterTargetLitres: coordinator.dailyPlan?.waterLitresTarget ?? GoalPresets[coordinator.currentGoalConfig.goal]?.waterLitres ?? 2.4,
                onLogWater: coordinator.addWater,
                backendIsWaking: coordinator.backendStatus == .waking,
                initialEditingMeal: coordinator.mealBeingEdited,
                initialSuggestedDescription: coordinator.logMealPrefill?.prefillDescription,
                initialSuggestedMealType: coordinator.logMealPrefill.flatMap { MealType(rawValue: $0.mealType) },
                calorieTarget: coordinator.dailyPlan?.kcalTarget ?? GoalPresets[coordinator.currentGoalConfig.goal]?.kcal ?? 1700,
                proteinTarget: coordinator.dailyPlan?.proteinTarget ?? GoalPresets[coordinator.currentGoalConfig.goal]?.protein ?? 120,
                currentCaloriesConsumed: coordinator.intake.kcal,
                currentProteinConsumed: Double(coordinator.intake.protein),
                goalType: coordinator.currentGoalConfig.goal.rawValue,
                healthConditions: coordinator.currentBaseline.medical
                    .filter { $0 != .none && $0 != .preferNotToSay }
                    .map(\.title),
                onSave: coordinator.didSaveMeal,
                onUpdate: coordinator.didUpdateMeal,
                onDelete: coordinator.didDeleteMeal
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $coordinator.showingWeeklyReview) {
            if let review = coordinator.weeklyReview {
                WeeklyReviewView(
                    review: review,
                    appliedFocusChips: coordinator.weeklyFocusChips,
                    onUseFocus: {
                        coordinator.applyWeeklyFocus(review.recommendationChips)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .overlay {
            if coordinator.isLoading {
                ProgressView()
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BeUTheme.cardBackground)
                    )
            } else if let transientMessage = coordinator.transientMessage {
                VStack {
                    Spacer()
                    Text(transientMessage)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BeUTheme.primaryText)
                        )
                        .padding(.bottom, 110)
                }
            }
        }
        .task { await coordinator.refreshAll() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await coordinator.warmUpBackendIfNeeded(force: true) }
        }
    }
}

private struct BeUHomeTabView: View {
    @ObservedObject var coordinator: EngineCoordinatorModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        BeUKicker(text: coordinator.dateLabel)
                        Spacer()
                    }
                    Text("Hi, \(coordinator.greetingName)")
                        .font(BeUTheme.greetingHeroFont)
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Here’s your plan for today.")
                        .font(BeUTheme.bodyFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }

                readinessCard
                targetsCard

                if coordinator.healthGateway.isConnected {
                    appleHealthCard
                }

                todayPlanCard
                if let preview = coordinator.nextBestMealResult?.primary {
                    nextBestMealPreview(preview)
                }
                weeklySnapshot
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 150)
        }
    }

    private var readinessCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 12) {
                BeUKicker(text: "Readiness")
                Text("\(coordinator.readiness.score)")
                    .font(.system(size: 56, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                HStack(spacing: 8) {
                    statusPill(text: coordinator.readiness.status.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
                    Text(coordinator.readiness.oneLineMessage)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                ForEach(Array(coordinator.readiness.contributingFactors.prefix(2)), id: \.self) { factor in
                    Text(factor)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BeUTheme.cardBackground, BeUTheme.accentSoft.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }

    private var targetsCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                BeUKicker(text: "Today's targets")
                if let plan = coordinator.dailyPlan {
                    compactTargetRow("Calories", "\(coordinator.intake.kcal)", "\(plan.kcalTarget)", progress(Double(coordinator.intake.kcal), Double(plan.kcalTarget)), BeUTheme.accent)
                    compactTargetRow("Protein", "\(coordinator.intake.protein)g", "\(plan.proteinTarget)g", progress(Double(coordinator.intake.protein), Double(plan.proteinTarget)), BeUTheme.warn)
                    compactTargetRow("Water", coordinator.formattedWaterValueText + "L", String(format: "%.1fL", plan.waterLitresTarget), progress(coordinator.intake.waterLitres, plan.waterLitresTarget), BeUTheme.ok)
                    compactTargetRow("Steps", "\(coordinator.intake.steps)", "\(plan.cardioStepsTarget)", progress(Double(coordinator.intake.steps), Double(plan.cardioStepsTarget)), BeUTheme.accent)
                }
            }
        }
    }

    private var appleHealthCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    BeUKicker(text: "From Apple Health")
                    Spacer()
                    Text(coordinator.healthGateway.lastSyncLabel)
                        .font(.system(size: 11))
                        .foregroundColor(BeUTheme.tertiaryText)
                }
                HStack(spacing: 12) {
                    signalBlock("Steps", value: "\(coordinator.intake.steps)", unit: "", subtitle: "today")
                    signalBlock("Sleep", value: String(format: "%.1f", coordinator.currentSignals.sleepHours), unit: "h", subtitle: "last night")
                    signalBlock("HRV", value: "\(coordinator.currentSignals.hrv)", unit: "ms", subtitle: "recovery")
                }
                HStack(spacing: 12) {
                    signalBlock("RHR", value: "\(coordinator.currentSignals.rhr)", unit: "bpm", subtitle: "resting")
                    signalBlock("Active", value: "\(Int((coordinator.healthGateway.todaySummary?.activeEnergyKcal ?? 0).rounded()))", unit: "kcal", subtitle: "burned")
                    Spacer()
                }
            }
        }
    }

    private var todayPlanCard: some View {
        Button {
            coordinator.selectedTab = .plan
        } label: {
            BeUCard {
                VStack(alignment: .leading, spacing: 14) {
                    BeUKicker(text: "Today's plan")
                    if let plan = coordinator.dailyPlan {
                        compactPlanRow(icon: "fork.knife", title: "Diet", value: plan.adaptivePlan.mealGuidance.dietFocus)
                        compactPlanRow(icon: "dumbbell.fill", title: "Strength", value: homeStrengthSummary(plan))
                        compactPlanRow(icon: "figure.walk", title: "Cardio", value: homeCardioSummary(plan))
                        compactPlanRow(icon: "drop.fill", title: "Water", value: String(format: "%.1fL", plan.waterLitresTarget))
                        compactPlanRow(icon: "moon.stars.fill", title: "Sleep", value: String(format: "%.1fh", coordinator.currentSignals.sleepTarget))
                        if let action = plan.adaptivePlan.nextBestActions.first {
                            compactPlanRow(icon: "sparkles", title: "Next", value: action.title)
                        }
                        if let delta = coordinator.dailyDelta {
                            compactPlanRow(icon: "arrow.triangle.branch", title: "Changed", value: delta.homePreview)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var weeklySnapshot: some View {
        Button {
            coordinator.showingWeeklyReview = true
        } label: {
            BeUCard {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        BeUKicker(text: "Weekly snapshot")
                        HStack(spacing: 24) {
                            snapshotMetric(label: "Avg readiness", value: "\(coordinator.weeklyInsights?.averageReadiness ?? coordinator.weeklyReadinessScores.last ?? 64)")
                            snapshotMetric(label: "Consistency", value: "\(coordinator.weeklyInsights?.consistencyScore ?? 78)/100")
                        }
                    }
                    Spacer()
                    Text("This week ›")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nextBestMealPreview(_ suggestion: NextBestMealSuggestion) -> some View {
        Button {
            coordinator.selectedTab = .plan
        } label: {
            BeUCard {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        BeUKicker(text: "Next best meal")
                        Text(suggestion.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                        Text("~\(suggestion.estimatedCalories) kcal · ~\(Int(suggestion.estimatedProteinGrams.rounded()))g protein")
                            .font(BeUTheme.helperFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                    Spacer()
                    Text("Plan ›")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statusPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundColor(BeUTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.7))
            )
    }

    private func signalBlock(_ title: String, value: String, unit: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(BeUTheme.kickerFont)
                .foregroundColor(BeUTheme.tertiaryText)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .light))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.primaryText)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(BeUTheme.tertiaryText)
            }
            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundColor(BeUTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planTile(icon: String, label: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BeUTheme.accent)
                    )
                Text(label.uppercased())
                    .font(BeUTheme.kickerFont)
                    .foregroundColor(BeUTheme.tertiaryText)
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundColor(BeUTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }

    private func snapshotMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(BeUTheme.tertiaryText)
            Text(value)
                .font(.system(size: 22, weight: .light))
                .monospacedDigit()
                .foregroundColor(BeUTheme.primaryText)
        }
    }

    private func progress(_ value: Double, _ target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    private func compactTargetRow(_ label: String, _ value: String, _ target: String, _ progressValue: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Spacer()
                Text("\(value) / \(target)")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(BeUTheme.secondaryText)
            }
            BeUTargetBar(label: "", valueText: "", targetText: "", progress: progressValue, tint: tint)
        }
    }

    private func compactPlanRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BeUTheme.accent.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                )
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13.5))
                .foregroundColor(BeUTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func homeStrengthSummary(_ plan: DailyPlan) -> String {
        let advice = plan.adaptivePlan.strengthAdvice
        if advice.durationMinutes <= 0 {
            return advice.recommendation
        }
        return "\(advice.durationMinutes) min \(advice.intensity.lowercased())"
    }

    private func homeCardioSummary(_ plan: DailyPlan) -> String {
        let advice = plan.adaptivePlan.activityAdvice
        if advice.stepsRemaining > 0, advice.cardioRecommendation == "Extra cardio is optional." {
            return advice.cardioRecommendation
        }
        if advice.stepsRemaining > 0 {
            return advice.cardioRecommendation
        }
        return "Light walk"
    }
}

private struct BeUPlanTabView: View {
    @ObservedObject var coordinator: EngineCoordinatorModel
    @State private var isWhyExpanded = false
    @State private var pendingDeleteMeal: MealLog?
    @State private var showingAlternatives = false
    @State private var showingDeltaDetail = false
    private let mealQualityService = MealQualityService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(kicker: "Plan", title: "Today")

                if let plan = coordinator.dailyPlan {
                    intakeBurnSection(plan)
                    adaptiveCoachSection(plan)
                    if let nextBest = coordinator.nextBestMealResult?.primary {
                        nextBestMealSection(nextBest)
                    }
                    if let dailyDelta = coordinator.dailyDelta {
                        WhatChangedTodayCard(delta: dailyDelta) {
                            showingDeltaDetail = true
                        }
                    }
                    waterSection(plan)
                    trainingSection(plan)

                    if coordinator.healthGateway.isConnected {
                        sleepSection
                    }

                    mealIdeasSection(plan)
                    prioritizeSection(plan)
                    supplementSection(plan)
                    whyThisPlanSection(plan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 150)
        }
        .confirmationDialog(
            "Delete meal?",
            isPresented: Binding(
                get: { pendingDeleteMeal != nil },
                set: { if !$0 { pendingDeleteMeal = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDeleteMeal else { return }
                Task {
                    _ = await coordinator.didDeleteMeal(pendingDeleteMeal)
                    await MainActor.run {
                        self.pendingDeleteMeal = nil
                    }
                }
            }
            .disabled(coordinator.deletingMealId != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the meal and update your daily calories and macros.")
        }
        .sheet(isPresented: $showingAlternatives) {
            if let result = coordinator.nextBestMealResult, let primary = result.primary {
                MealAlternativesSheet(
                    primaryMeal: primary.name,
                    alternates: result.alternates,
                    savedMeals: coordinator.savedMealsForLater,
                    onLog: { suggestion in
                        showingAlternatives = false
                        coordinator.openLogMeal(prefill: suggestion)
                    },
                    onSave: coordinator.saveMealForLater
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingDeltaDetail) {
            if let delta = coordinator.dailyDelta {
                WhyThisChangedSheet(delta: delta)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func intakeBurnSection(_ plan: DailyPlan) -> some View {
        planSection(title: "Intake & Burn") {
            VStack(alignment: .leading, spacing: 12) {
                BeUTargetBar(
                    label: "Calories eaten",
                    valueText: "\(plan.energyBalance.caloriesConsumed)",
                    targetText: "\(plan.energyBalance.calorieIntakeTarget) kcal",
                    progress: min(Double(plan.energyBalance.caloriesConsumed) / Double(max(plan.energyBalance.calorieIntakeTarget, 1)), 1),
                    tint: BeUTheme.warn
                )
                BeUTargetBar(
                    label: "Calories burned",
                    valueText: "\(plan.energyBalance.estimatedTotalBurn)",
                    targetText: "\(plan.energyBalance.dailyBurnTarget) kcal",
                    progress: min(Double(plan.energyBalance.estimatedTotalBurn) / Double(max(plan.energyBalance.dailyBurnTarget, 1)), 1),
                    tint: BeUTheme.ok
                )
                HStack(spacing: 12) {
                    statColumn("Workout burn", "\(plan.energyBalance.workoutEnergyBurned) kcal")
                    statColumn("Burn left", "\(plan.energyBalance.remainingBurnTarget) kcal")
                    statColumn("Calories left", intakeRemainingText(plan))
                }
                Text("Workout burn is shown separately and not double-counted.")
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private func waterSection(_ plan: DailyPlan) -> some View {
        planSection(title: "Water Intake") {
            VStack(alignment: .leading, spacing: 12) {
                BeUTargetBar(
                    label: "Water",
                    valueText: coordinator.formattedWaterValueText + "L",
                    targetText: String(format: "%.1fL", plan.waterLitresTarget),
                    progress: min(coordinator.intake.waterLitres / max(plan.waterLitresTarget, 0.1), 1),
                    tint: BeUTheme.ok
                )
                HStack(spacing: 12) {
                    statColumn("Remaining", waterRemainingText(plan))
                    statColumn("Next", nextWaterAction(plan))
                }
            }
        }
    }

    private func adaptiveCoachSection(_ plan: DailyPlan) -> some View {
        planSection(title: "Adaptive Coach Update") {
            VStack(alignment: .leading, spacing: 12) {
                Text(adaptivePlanModeMessage(plan))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                if let action = plan.adaptivePlan.nextBestActions.first {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Next best action:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BeUTheme.secondaryText)
                        Text(action.title)
                            .font(.system(size: 13))
                            .foregroundColor(BeUTheme.primaryText)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(plan.adaptivePlan.nudges.prefix(3))) { nudge in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(BeUTheme.accent)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(nudge.message)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }
                if coordinator.weeklyFocusChips.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This week’s focus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BeUTheme.secondaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(coordinator.weeklyFocusChips, id: \.self) { chip in
                                Text(chip)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule(style: .continuous).fill(BeUTheme.accent.opacity(0.14)))
                            }
                        }
                    }
                }
            }
        }
    }

    private func nextBestMealSection(_ suggestion: NextBestMealSuggestion) -> some View {
        NextBestMealCard(
            suggestion: suggestion,
            isSaved: coordinator.isMealSavedForLater(suggestion),
            onLog: { coordinator.openLogMeal(prefill: suggestion) },
            onSave: { coordinator.saveMealForLater(suggestion) },
            onAlternatives: { showingAlternatives = true }
        )
    }

    private func trainingSection(_ plan: DailyPlan) -> some View {
        planSection(title: "Today's Training") {
            VStack(spacing: 12) {
                activityCard(
                    icon: "dumbbell.fill",
                    title: adaptiveStrengthTitle(plan),
                    subtitle: adaptiveStrengthSubtitle(plan)
                )
                activityCard(
                    icon: "figure.walk",
                    title: adaptiveCardioTitle(plan),
                    subtitle: adaptiveCardioSubtitle(plan)
                )
            }
        }
    }

    private var sleepSection: some View {
        planSection(title: "Sleep Requirement") {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(BeUTheme.accent)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aim for \(String(format: "%.1f", coordinator.currentSignals.sleepTarget))h tonight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text(sleepMessage)
                        .font(.system(size: 12.5))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Spacer()
                Text(String(format: "Last: %.1fh", coordinator.currentSignals.sleepHours))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(sleepStatusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(sleepStatusColor.opacity(0.12))
                    )
            }
        }
    }

    private func mealIdeasSection(_ plan: DailyPlan) -> some View {
        let guidance = plan.dietGuidance
        return planSection(title: "Meal ideas for today") {
            VStack(alignment: .leading, spacing: 12) {
                Text(plan.adaptivePlan.mealGuidance.nextMealStrategy)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
                mealTypeSection(.breakfast, suggestions: Array(guidance.mealSuggestionsByType.breakfast.prefix(2)))
                mealTypeSection(.dinner, suggestions: Array(guidance.mealSuggestionsByType.dinner.prefix(2)))
                mealTypeSection(.snack, suggestions: Array(guidance.mealSuggestionsByType.snacks.prefix(2)))
            }
        }
    }

    private func prioritizeSection(_ plan: DailyPlan) -> some View {
        let guidance = plan.dietGuidance
        let actions = Array(shortActionBullets(guidance).prefix(2))
        return planSection(title: "What to prioritize today") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(Array(guidance.foodGroupsToPrioritize.prefix(3)), id: \.self) { item in
                        Text(item)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule(style: .continuous).fill(BeUTheme.accent.opacity(0.14)))
                    }
                }
                ForEach(actions, id: \.self) { action in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(BeUTheme.primaryText)
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)
                        Text(action)
                            .font(BeUTheme.bodyFont)
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }
                if let note = conciseHealthNote(plan) {
                    Text(note)
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Text(plan.adaptivePlan.mealGuidance.dietFocus)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
        }
    }

    private func supplementSection(_ plan: DailyPlan) -> some View {
        let supplements = coordinator.currentBaseline.supplements.filter { $0.isActive }
        return planSection(title: "Supplement Reminder") {
            if supplements.isEmpty {
                Text("No supplement reminders right now.")
                    .font(BeUTheme.bodyFont)
                    .foregroundColor(BeUTheme.secondaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(supplements, id: \.id) { supplement in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.03))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "pills.fill")
                                        .foregroundColor(BeUTheme.accent)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(supplement.name)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                                Text(supplementTiming(supplement))
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                                Text("Status: \(supplementStatus(for: supplement))")
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                            Spacer()
                            Button(coordinator.isSupplementTaken(supplement) ? "Undo" : "Mark taken") {
                                if coordinator.isSupplementTaken(supplement) {
                                    coordinator.undoSupplementTaken(supplement)
                                } else {
                                    coordinator.markSupplementTaken(supplement)
                                }
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(coordinator.isSupplementTaken(supplement) ? BeUTheme.tertiaryText : BeUTheme.primaryText)
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func whyThisPlanSection(_ plan: DailyPlan) -> some View {
        planSection(title: "Why this plan?") {
            DisclosureGroup(isExpanded: $isWhyExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(plan.explanation.prefix(3)), id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(BeUTheme.primaryText)
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)
                            Text(line)
                                .font(BeUTheme.helperFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Why this plan?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
            }
        }
    }

    private var sleepMessage: String {
        let diff = coordinator.currentSignals.sleepTarget - coordinator.currentSignals.sleepHours
        if diff > 0.5 {
            return "Sleep was \(String(format: "%.1f", diff))h below your baseline — wind down 30 min earlier tonight."
        }
        return "Sleep is on track — keep the rhythm."
    }

    private var sleepStatusColor: Color {
        coordinator.currentSignals.sleepHours < coordinator.currentSignals.sleepTarget - 0.5 ? BeUTheme.alert : BeUTheme.ok
    }

    private func mealTypeSection(_ mealType: MealType, suggestions: [MealSuggestion]) -> some View {
        let loggedMeals = coordinator.mealsToday.filter { $0.mealType == mealType }

        return VStack(alignment: .leading, spacing: 10) {
            Text(mealType.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)

            if loggedMeals.isEmpty {
                ForEach(suggestions) { suggestion in
                    mealSuggestionCard(suggestion)
                }
            } else {
                ForEach(loggedMeals) { meal in
                    loggedMealCard(meal, plan: coordinator.dailyPlan)
                }
            }
        }
    }

    private func loggedMealCard(_ meal: MealLog, plan: DailyPlan?) -> some View {
        let quality = plan.map {
            mealQualityService.scoreMeal(
                items: meal.items,
                context: MealQualityContext(
                    mealType: meal.mealType,
                    goalType: coordinator.currentGoalConfig.goal.rawValue,
                    calorieTarget: $0.kcalTarget,
                    proteinTarget: $0.proteinTarget,
                    caloriesRemaining: nil,
                    proteinRemaining: nil,
                    healthConditions: coordinator.currentBaseline.medical
                        .filter { $0 != .none && $0 != .preferNotToSay }
                        .map(\.title)
                )
            )
        } ?? nil

        return LoggedMealCardView(
            meal: meal,
            quality: quality,
            onEdit: { coordinator.editMeal(meal) },
            onDelete: { pendingDeleteMeal = meal },
            isDeleting: coordinator.deletingMealId == meal.id
        )
    }

    private func mealSummary(_ meal: MealLog) -> String {
        let names = meal.items.prefix(3).map(\.name)
        if names.isEmpty { return meal.mealType.title }
        let summary = names.joined(separator: ", ")
        return meal.items.count > 3 ? "\(summary)..." : summary
    }

    private func mealSuggestionCard(_ suggestion: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Portion: \(portionText(for: suggestion))")
                        .font(.system(size: 12.5))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Approx. \(suggestion.estimatedCalories) kcal")
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Approx. \(suggestion.estimatedProteinGrams)g protein")
                        .font(BeUTheme.helperFont)
                        .foregroundColor(BeUTheme.secondaryText)
                }
            }

            HStack(spacing: 8) {
                if suggestion.estimatedProteinGrams >= 25 {
                    suggestionBadge("High protein")
                }
                if let conditionFitNote = suggestion.conditionFitNote, !conditionFitNote.isEmpty {
                    suggestionBadge("Fits context")
                }
                if let readinessFitNote = suggestion.readinessFitNote, !readinessFitNote.isEmpty {
                    suggestionBadge("Balanced today")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }

    private func suggestionBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(BeUTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(BeUTheme.accent.opacity(0.12))
            )
    }

    private func intakeRemainingText(_ plan: DailyPlan) -> String {
        let remaining = plan.kcalTarget - coordinator.intake.kcal
        return remaining >= 0 ? "\(remaining) kcal" : "Over by \(abs(remaining)) kcal"
    }

    private func waterRemainingText(_ plan: DailyPlan) -> String {
        let remaining = max(plan.waterLitresTarget - coordinator.intake.waterLitres, 0)
        return String(format: "%.1fL left", remaining)
    }

    private func nextWaterAction(_ plan: DailyPlan) -> String {
        let remaining = max(plan.waterLitresTarget - coordinator.intake.waterLitres, 0)
        if remaining >= 1.0 { return "500ml before next meal" }
        if remaining >= 0.5 { return "300ml in the next hour" }
        return "Small sip break"
    }

    private func adaptivePlanModeMessage(_ plan: DailyPlan) -> String {
        switch plan.adaptivePlan.planMode {
        case "activity_ahead":
            return "Activity is ahead today. Keep calories steady and focus on protein."
        case "activity_behind":
            return "Movement is behind for the time of day. Use a practical walk to course-correct."
        case "protein_behind":
            return "Protein is behind today. Keep the next meal protein-led."
        case "calories_tight":
            return "Calories are tight, so the rest of the day should stay lean and efficient."
        case "recovery_first":
            return "Recovery is lower today. Keep the day balanced and avoid chasing burn."
        case "refuel_needed":
            return "You trained today. Keep calories steady and make the next meal protein-led."
        default:
            return "You’re broadly on track. Stay steady with meals, movement, and recovery."
        }
    }

    private func adaptiveStrengthTitle(_ plan: DailyPlan) -> String {
        let advice = plan.adaptivePlan.strengthAdvice
        if advice.durationMinutes <= 0 {
            return advice.recommendation
        }
        let burn = advice.estimatedBurnKcal.map { " · approx. \($0) kcal" } ?? ""
        return "\(advice.durationMinutes) min · \(advice.intensity.capitalized)\(burn)"
    }

    private func adaptiveStrengthSubtitle(_ plan: DailyPlan) -> String {
        plan.adaptivePlan.strengthAdvice.message
    }

    private func adaptiveCardioTitle(_ plan: DailyPlan) -> String {
        let advice = plan.adaptivePlan.activityAdvice
        let burn = advice.estimatedCardioBurnKcal.map { " · approx. \($0) kcal" } ?? ""
        return advice.cardioRecommendation + burn
    }

    private func adaptiveCardioSubtitle(_ plan: DailyPlan) -> String {
        let advice = plan.adaptivePlan.activityAdvice
        if advice.stepsRemaining > 0 {
            return "\(advice.stepsRemaining) steps remaining"
        }
        return advice.message
    }

    private func conciseHealthNote(_ plan: DailyPlan) -> String? {
        guard let note = plan.healthContextNote else { return nil }
        if note.contains("PCOS") {
            return "PCOS context: keep meals balanced and protein-led."
        }
        return note
    }

    private func shortActionBullets(_ guidance: DietGuidance) -> [String] {
        var actions: [String] = []
        actions.append(guidance.nextMealStrategy)
        if let first = guidance.targetContext.split(separator: ".").first {
            actions.append(String(first) + ".")
        }
        return actions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func supplementTiming(_ supplement: Supplement) -> String {
        let timing = supplement.timeOfDay?.title ?? "Any time"
        return supplement.timeOfDay == .withMeal ? "\(timing)" : "\(timing)\(supplement.timeOfDay == .beforeBed ? "" : "")"
    }

    private func supplementStatus(for supplement: Supplement) -> String {
        if coordinator.isSupplementTaken(supplement) { return "Taken" }
        if let time = supplement.timeOfDay, time == currentTimeBand() || time == .withMeal {
            return "Due today"
        }
        return "Due later"
    }

    private func currentTimeBand() -> SupplementTime {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    private func portionText(for suggestion: MealSuggestion) -> String {
        let lower = suggestion.name.lowercased()
        if lower.contains("roti") { return "1 bowl + 1 roti" }
        if lower.contains("curd") || lower.contains("hung curd") { return "1 bowl" }
        if lower.contains("smoothie") || lower.contains("shake") { return "1 glass" }
        if lower.contains("cubes") { return "1 serving" }
        return "1 serving"
    }

    private func activityCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BeUTheme.accent.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(BeUTheme.accent)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(BeUTheme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BeUTheme.cardAltBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BeUTheme.hairline, lineWidth: 0.5)
                )
        )
    }
}

private struct BeUProgressTabView: View {
    @ObservedObject var coordinator: EngineCoordinatorModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(kicker: "Progress", title: "Weekly")

                readinessBarChartCard

                if coordinator.weeklyReview != nil {
                    BeUCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                BeUKicker(text: "Weekly review")
                                Text("View weekly review")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(BeUTheme.primaryText)
                                Text("See hit days, focus areas, and next-week adjustments.")
                                    .font(BeUTheme.helperFont)
                                    .foregroundColor(BeUTheme.secondaryText)
                            }
                            Spacer()
                            Button("Open") {
                                coordinator.showingWeeklyReview = true
                            }
                            .buttonStyle(BeUSecondaryButtonStyle())
                        }
                    }
                }

                if let energy = coordinator.weeklyInsights?.weeklyEnergySummary {
                    BeUCard {
                        VStack(alignment: .leading, spacing: 14) {
                            BeUKicker(text: "Weekly trend")
                            HStack(spacing: 16) {
                                statColumn("Avg eaten", "\(energy.avgCaloriesConsumed)")
                                statColumn("Avg burned", "\(energy.avgEstimatedBurn)")
                            }
                            HStack(spacing: 16) {
                                statColumn("Burn target", "\(energy.avgBurnTarget)")
                                statColumn("Days met", "\(energy.daysBurnTargetMet)/7")
                            }
                            Text(energy.message)
                                .font(BeUTheme.bodyFont)
                                .foregroundColor(BeUTheme.secondaryText)
                        }
                    }
                }

                BeUCard {
                    VStack(alignment: .leading, spacing: 10) {
                        BeUKicker(text: "Consistency")
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(coordinator.weeklyInsights?.consistencyScore ?? 78)")
                                .font(.system(size: 44, weight: .light))
                                .monospacedDigit()
                                .foregroundColor(BeUTheme.primaryText)
                            Text("/100")
                                .font(.system(size: 18))
                                .foregroundColor(BeUTheme.tertiaryText)
                        }
                        Text("Strong consistency — keep showing up.")
                            .font(.system(size: 13.5))
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                }

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 150)
        }
    }

    private var readinessBarChartCard: some View {
        BeUCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        BeUKicker(text: "Readiness trend")
                        Text(coordinator.weeklyInsights?.trendLabel ?? "Weekly trend")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(BeUTheme.primaryText)
                    }
                    Spacer()
                    Text("Avg \(coordinator.weeklyInsights?.averageReadiness ?? averageReadiness)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                ReadinessBarChart(values: coordinator.weeklyReadinessScores)
                    .frame(height: 170)
            }
        }
    }

    private var averageReadiness: Int {
        let values = coordinator.weeklyReadinessScores
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

private struct BeUMeTabView: View {
    @ObservedObject var coordinator: EngineCoordinatorModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Image("BeULogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 30)
                        .accessibilityLabel("BeU logo")
                    BeUKicker(text: "BeU profile")
                    Text("About you")
                        .font(BeUTheme.greetingHeroFont)
                        .foregroundColor(BeUTheme.primaryText)
                }

                identityCard
                baselineCard
                goalCard
                healthDataCard

                Text(BeUSafetyCopy.wellnessDisclaimer)
                    .font(BeUTheme.helperFont)
                    .foregroundColor(BeUTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 150)
        }
    }

    private var identityCard: some View {
        BeUCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BeUTheme.accentSoft, BeUTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image("BeULogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 18)
                            .accessibilityLabel("BeU logo")
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.currentBaseline.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text("Goal · \(coordinator.goalLabel)")
                        .font(.system(size: 13.5))
                        .foregroundColor(BeUTheme.secondaryText)
                }
                Spacer()
            }
        }
    }

    private var baselineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BeUKicker(text: "Baseline profile")
                Spacer()
                Text("READ-ONLY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(BeUTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
            }

            BeUCard {
                VStack(spacing: 14) {
                    meRow("Name", coordinator.currentBaseline.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : coordinator.currentBaseline.name)
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Gender", coordinator.currentBaseline.gender.title)
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Age", "\(coordinator.currentBaseline.age)")
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Height", "\(coordinator.currentBaseline.heightCm) cm")
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Weight", "\(coordinator.currentBaseline.weightKg) kg")
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Health context", coordinator.currentBaseline.medicalDisplay)
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Supplements", "\(coordinator.currentBaseline.supplements.count) added")
                }
            }

            Button("Review baseline →") {
                coordinator.reopenBaseline()
            }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundColor(BeUTheme.primaryText)
            .buttonStyle(.plain)

            Text("These inputs form your long-term baseline. Update only when something changes.")
                .font(BeUTheme.helperFont)
                .foregroundColor(BeUTheme.secondaryText)
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BeUKicker(text: "Current goal")
                Spacer()
                Button("Change ›") { coordinator.changeGoal() }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(BeUTheme.primaryText)
                    .buttonStyle(.plain)
            }

            BeUCard {
                VStack(spacing: 14) {
                    meRow("Goal", coordinator.goalLabel)
                    if let targetWeight = coordinator.currentGoalConfig.targetWeightKg {
                        Divider().overlay(BeUTheme.hairline)
                        meRow("Target weight", "\(targetWeight) kg")
                    }
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Timeline", coordinator.currentGoalConfig.timeline.displayValue(customYears: coordinator.currentGoalConfig.customYears))
                    if let plan = coordinator.dailyPlan {
                        Divider().overlay(BeUTheme.hairline)
                        meRow("Daily calories", "\(plan.kcalTarget)")
                        Divider().overlay(BeUTheme.hairline)
                        meRow("Daily protein", "\(plan.proteinTarget)g")
                    }
                }
            }
        }
    }

    private var healthDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeUKicker(text: "Health data")
            BeUCard {
                VStack(spacing: 14) {
                    meRow("Apple Health", coordinator.healthGateway.isConnected ? "Connected" : "Prototype data")
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Backend", coordinator.backendStatus.label)
                    Divider().overlay(BeUTheme.hairline)
                    meRow("Last synced", coordinator.healthGateway.lastSyncLabel)
                }
            }
        }
    }

    private func meRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(BeUTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
        }
    }
}

private struct BeULogWaterButton: View {
    let litres: Double
    let target: Double
    let onTap: () -> Bool

    @State private var burstIDs: [UUID] = []
    @State private var pulseToken = UUID()
    @State private var isBurstVisible = false

    var body: some View {
        Button {
            guard onTap() else { return }
            let burstID = UUID()
            pulseToken = UUID()
            burstIDs.append(burstID)
            withAnimation(.easeInOut(duration: 0.12)) {
                isBurstVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isBurstVisible = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                burstIDs.removeAll { $0 == burstID }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(BeUTheme.accent, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                        .id(pulseToken)
                        .modifier(BeUPulseModifier(token: pulseToken))

                    Image(systemName: "drop.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(BeUTheme.accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Log water")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BeUTheme.primaryText)
                    Text(subline)
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(BeUTheme.tertiaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeUTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BeUTheme.hairline, lineWidth: 0.5)
                    )
            )
            .overlay(alignment: .topTrailing) {
                ZStack(alignment: .topTrailing) {
                    ForEach(burstIDs, id: \.self) { burstID in
                        BeUWaterBurstView(id: burstID)
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 12)
            }
            .scaleEffect(isBurstVisible ? 0.97 : 1)
        }
        .buttonStyle(.plain)
    }

    private var subline: String {
        let value = litres < 1 ? String(format: "%.2f", litres) : String(format: "%.1f", litres)
        let percentage = min(100, Int((litres / max(target, 0.1)) * 100))
        return "\(value)/\(String(format: "%.1f", target))L · \(percentage)%"
    }
}

private struct BeUPulseModifier: ViewModifier {
    let token: UUID
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.7

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear { run() }
            .onChange(of: token) { _, _ in run() }
    }

    private func run() {
        scale = 0.6
        opacity = 0.7
        withAnimation(.easeOut(duration: 0.7)) {
            scale = 1.6
            opacity = 0
        }
    }
}

private struct BeUWaterBurstView: View {
    let id: UUID

    @State private var opacity = 0.0
    @State private var offsetY: CGFloat = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Text("+100 ml")
            .font(.system(size: 12, weight: .bold))
            .monospacedDigit()
            .foregroundColor(BeUTheme.ok)
            .opacity(opacity)
            .offset(y: offsetY)
            .scaleEffect(scale)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.135) {
                    withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.135)) {
                        opacity = 1
                        offsetY = -4
                        scale = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                        withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.75)) {
                            opacity = 0
                            offsetY = -26
                            scale = 1
                        }
                    }
                }
            }
    }
}

private struct ReadinessBarChart: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(values.max() ?? 100, 100)
            let width = max((proxy.size.width - CGFloat(max(values.count - 1, 0)) * 10) / CGFloat(max(values.count, 1)), 18)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == values.count - 1 ? BeUTheme.accent : BeUTheme.accent.opacity(0.4))
                            .frame(width: width, height: max(12, (CGFloat(value) / CGFloat(maxValue)) * 120))
                        Text(dayLabel(index))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(BeUTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func dayLabel(_ index: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let calendar = Calendar.current
        let offset = (values.count - 1) - index
        let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let weekday = calendar.component(.weekday, from: date) - 1
        return symbols.indices.contains(weekday) ? String(symbols[weekday].prefix(3)) : ""
    }
}

private func tabHeader(kicker: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        BeUKicker(text: kicker)
        Text(title)
            .font(BeUTheme.greetingHeroFont)
            .foregroundColor(BeUTheme.primaryText)
    }
}

private func planSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    BeUCard {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(BeUTheme.primaryText)
            content()
        }
    }
}

private func activitySummaryRow(title: String, detail: String) -> some View {
    HStack {
        Text(title)
            .font(BeUTheme.bodyFont)
            .foregroundColor(BeUTheme.secondaryText)
        Spacer()
        Text(detail)
            .font(BeUTheme.bodyFont.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(BeUTheme.primaryText)
    }
}

private func statColumn(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(BeUTheme.helperFont)
            .foregroundColor(BeUTheme.tertiaryText)
        Text(value)
            .font(.system(size: 22, weight: .light))
            .monospacedDigit()
            .foregroundColor(BeUTheme.primaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private extension Baseline {
    var medicalDisplay: String {
        let filtered = medical.filter { $0 != .none && $0 != .preferNotToSay }
        if medical.contains(.preferNotToSay) { return "Prefer not to say" }
        if filtered.isEmpty { return "None" }
        return filtered.map(\.title).joined(separator: ", ")
    }
}
