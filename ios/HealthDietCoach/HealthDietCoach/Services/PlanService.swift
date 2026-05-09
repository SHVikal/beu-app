import Foundation

fileprivate struct DietGuidanceContext {
    let userId: String
    let date: String
    let dayOfWeek: String
    let baseline: Baseline
    let goalConfig: GoalConfig
    let intake: DailyIntake
    let readiness: Readiness
    let signals: HealthSignals
    let summary: HealthSummary?
    let recentSummaries: [HealthSummary]
    let mealsLoggedToday: [MealLog]
    let suggestionHistory: [DietSuggestionHistory]
    let energyBalance: DailyEnergyBalance
    let calorieTarget: Int
    let proteinTarget: Int
    let waterTarget: Double
    let stepTarget: Int
}

fileprivate struct MealLibraryItem {
    let name: String
    let mealType: String
    let description: String
    let calories: Int
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
    let tags: [String]
    let dietTypes: [DietPreference]
    let conditionsFit: [Condition]
    let goalFit: [Goal]
}

final class DietGuidanceService {
    private let forbiddenMedicalLanguage = [
        "diagnose", "prescribe", "dosage", "start taking", "stop taking", "interaction", "insulin", "treat",
    ]
    private let historyService: DietSuggestionHistoryService

    init(historyService: DietSuggestionHistoryService = DietSuggestionHistoryService()) {
        self.historyService = historyService
    }

    fileprivate func buildGuidance(from context: DietGuidanceContext) -> DietGuidance {
        let caloriesRemaining = max(0, context.energyBalance.calorieIntakeTarget - context.energyBalance.caloriesConsumed)
        let proteinRemaining = max(0, context.proteinTarget - context.intake.protein)
        let activeConditions = sanitizedConditions(context.baseline.medical)
        let hadRecentWorkout = workoutCompleted(for: context)
        let activityLevel = inferredActivityLevel(from: context.recentSummaries, todaySteps: context.summary?.steps ?? context.intake.steps)
        let aggressiveTimeline = isAggressiveTimeline(goalConfig: context.goalConfig, currentWeight: context.baseline.weightKg)
        let mealSuggestionsByType = MealSuggestionsByType(
            breakfast: suggestions(for: .breakfast, context: context, conditions: activeConditions, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, aggressiveTimeline: aggressiveTimeline),
            lunch: suggestions(for: .lunch, context: context, conditions: activeConditions, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, aggressiveTimeline: aggressiveTimeline),
            dinner: suggestions(for: .dinner, context: context, conditions: activeConditions, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, aggressiveTimeline: aggressiveTimeline),
            snacks: suggestions(for: .snack, context: context, conditions: activeConditions, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, aggressiveTimeline: aggressiveTimeline)
        )

        let dietPriority = buildDietPriority(goal: context.goalConfig.goal, preference: context.baseline.dietPreference, lowReadiness: context.readiness.status == .low)
        let targetContext = buildTargetContext(
            context: context,
            caloriesRemaining: caloriesRemaining,
            proteinRemaining: proteinRemaining,
            aggressiveTimeline: aggressiveTimeline
        )
        let readinessContext = buildReadinessContext(readiness: context.readiness, hadRecentWorkout: hadRecentWorkout)
        let healthContext = buildHealthContext(
            conditions: activeConditions,
            readiness: context.readiness,
            signals: context.signals,
            hadRecentWorkout: hadRecentWorkout
        )
        let metadataContext = buildMetadataContext(
            baseline: context.baseline,
            activityLevel: activityLevel,
            aggressiveTimeline: aggressiveTimeline
        )
        let nextMealStrategy = buildNextMealStrategy(
            context: context,
            conditions: activeConditions,
            caloriesRemaining: caloriesRemaining,
            proteinRemaining: proteinRemaining,
            hadRecentWorkout: hadRecentWorkout
        )

        let prioritize = prioritizedFoodGroups(
            goal: context.goalConfig.goal,
            conditions: activeConditions,
            readiness: context.readiness,
            hadRecentWorkout: hadRecentWorkout,
            activityLevel: activityLevel
        )
        var limit = limitedFoodGroups(
            goal: context.goalConfig.goal,
            conditions: activeConditions,
            caloriesRemaining: caloriesRemaining,
            readiness: context.readiness
        )

        if activeConditions.contains(.eatingDisorderHistory) {
            limit = []
        }

        let supplementNotes = buildSupplementContextNotes(from: context.baseline.supplements)
        let safetyNote = buildSafetyNote(for: activeConditions)

        historyService.recordSuggestions(
            userId: context.userId,
            date: context.date,
            suggestionsByType: mealSuggestionsByType
        )

        return DietGuidance(
            date: context.date,
            dayOfWeek: context.dayOfWeek,
            dietPriority: sanitize(dietPriority),
            targetContext: sanitize(targetContext),
            readinessContext: sanitize(readinessContext),
            metadataContext: sanitize(metadataContext),
            healthContext: sanitize(healthContext),
            nextMealStrategy: sanitize(nextMealStrategy),
            mealSuggestionsByType: sanitize(mealSuggestionsByType),
            foodGroupsToPrioritize: prioritize.map(sanitize),
            foodGroupsToLimit: limit.map(sanitize),
            supplementContextNotes: supplementNotes.map(sanitize),
            safetyNote: sanitize(safetyNote)
        )
    }

    private func buildDietPriority(goal: Goal, preference: DietPreference, lowReadiness: Bool) -> String {
        let prefix: String
        switch preference {
        case .indianVegetarian:
            prefix = "Protein-led Indian vegetarian meals"
        case .vegetarian:
            prefix = "Protein-led vegetarian meals"
        case .vegan:
            prefix = "Protein-led vegan meals"
        case .noPreference:
            prefix = "Balanced protein-led meals"
        }
        if lowReadiness {
            return "\(prefix) with balanced recovery support"
        }
        switch goal {
        case .fatLoss:
            return prefix
        case .muscle:
            return "\(prefix) with training refuel support"
        case .maintain, .wellness:
            return "Balanced meals with steady protein"
        }
    }

    private func buildTargetContext(
        context: DietGuidanceContext,
        caloriesRemaining: Int,
        proteinRemaining: Int,
        aggressiveTimeline: Bool
    ) -> String {
        let goalLabel = GoalPresets[context.goalConfig.goal]?.label.lowercased() ?? context.goalConfig.goal.title.lowercased()
        let base: String
        switch context.goalConfig.goal {
        case .fatLoss:
            base = "Your \(goalLabel) target and \(context.proteinTarget)g protein goal mean your next meal should be protein-dense while staying within your remaining \(caloriesRemaining) calories."
        case .muscle:
            base = "Your \(goalLabel) target and \(context.proteinTarget)g protein goal mean the next meal should support protein and enough energy for recovery."
        case .maintain:
            base = "Your maintenance target favors balanced meals, steady protein, and consistency across the day."
        case .wellness:
            base = "Your wellness target favors balanced meals, hydration, and regular eating patterns."
        }
        if aggressiveTimeline {
            if context.goalConfig.goal == .fatLoss {
                return base + " Your target timeline looks aggressive, so BeU is keeping meal guidance moderate and sustainable."
            }
            if context.goalConfig.goal == .muscle {
                return base + " BeU is using a steady surplus approach rather than pushing extreme intake."
            }
        }
        if proteinRemaining > 40 && context.goalConfig.goal == .fatLoss {
            return base + " Protein is still meaningfully behind, so the next meal should solve that first."
        }
        return base
    }

    private func buildReadinessContext(readiness: Readiness, hadRecentWorkout: Bool) -> String {
        switch readiness.status {
        case .high, .good:
            if readiness.usedDefaultSleep {
                return "Recovery looks steady based on the available data, so meals can stay balanced and practical."
            }
            if hadRecentWorkout {
                return "Recovery looks solid and you trained recently, so protein plus a moderate carb portion fits well."
            }
            return "Recovery looks solid, so meals can follow your normal goal-based plan."
        case .moderate:
            return "Recovery is mixed, so the meal strategy stays balanced rather than extreme."
        case .low:
            return "Readiness is lower today, so meals should feel balanced, easy, and steady."
        case .limitedData:
            return "Recovery data is limited, so meal ideas lean on your goal and remaining targets instead."
        }
    }

    private func buildHealthContext(
        conditions: [Condition],
        readiness: Readiness,
        signals: HealthSignals,
        hadRecentWorkout: Bool
    ) -> String {
        if conditions.contains(.pregnancy) {
            return "Pregnancy is in your health history, so BeU keeps meal guidance general, steady, and recovery-aware."
        }
        if conditions.contains(.eatingDisorderHistory) {
            return "Because eating disorder history is in your health history, BeU keeps the meal plan focused on regular nourishment, hydration, and recovery."
        }
        if conditions.contains(.pcos) {
            return "Because PCOS is in your health history, BeU prioritizes balanced meals, protein, fiber, hydration, and consistency."
        }
        if conditions.contains(.diabetes) {
            return "Because diabetes is in your health history, BeU keeps the meal strategy balanced and avoids strong carb-loading language."
        }
        if (!readiness.usedDefaultSleep && signals.sleepHours < signals.sleepTarget - 0.5) || readiness.status == .low {
            return "Recovery is lower today, so BeU keeps the meal strategy balanced."
        }
        if readiness.status == .limitedData {
            return "Some recovery data is still syncing, so BeU keeps the meal strategy balanced and easy to adjust."
        }
        if hadRecentWorkout {
            return "Because you trained recently, prioritize protein and include a moderate carb portion."
        }
        return "Today's meal guidance stays general, balanced, and easy to follow."
    }

    private func buildMetadataContext(
        baseline: Baseline,
        activityLevel: String,
        aggressiveTimeline: Bool
    ) -> String {
        var parts = [
            "Your daily targets are scaled to your current weight, height, activity level, and timeline.",
        ]
        if baseline.age >= 40 {
            parts.append("BeU also emphasizes spreading protein across meals rather than clustering it late.")
        }
        if activityLevel == "sedentary" || activityLevel == "light" {
            parts.append("Because your recent activity is lighter, meal ideas focus on fullness and protein without excess calories.")
        } else {
            parts.append("Because your recent activity is moderate to active, balanced carb portions still fit the plan.")
        }
        if aggressiveTimeline {
            parts.append("The timeline adds a sustainability check so the plan stays moderate.")
        }
        return parts.joined(separator: " ")
    }

    private func buildNextMealStrategy(
        context: DietGuidanceContext,
        conditions: [Condition],
        caloriesRemaining: Int,
        proteinRemaining: Int,
        hadRecentWorkout: Bool
    ) -> String {
        let proteinLead: String
        switch context.baseline.dietPreference {
        case .vegan:
            proteinLead = "Choose tofu, soya, dal, chickpeas, or sprouts with vegetables."
        default:
            proteinLead = "Choose paneer, tofu, soya, or dal with vegetables."
        }

        let carbLine: String
        if conditions.contains(.diabetes) || context.goalConfig.goal == .fatLoss || caloriesRemaining < 500 {
            carbLine = "Keep rice or roti portions moderate."
        } else if context.goalConfig.goal == .muscle && hadRecentWorkout {
            carbLine = "Include a moderate carb portion to support training recovery."
        } else {
            carbLine = "Build in a balanced carb portion that matches the day."
        }

        if context.readiness.status == .low {
            return "\(proteinLead) Keep the meal easy to digest and balanced. \(carbLine)"
        }
        if context.readiness.status == .limitedData {
            return "\(proteinLead) Keep the meal balanced and adjust portions based on hunger and the rest of your day. \(carbLine)"
        }
        if caloriesRemaining < 300 && proteinRemaining > 25 {
            return "\(proteinLead) Keep the meal compact, lean, and protein-focused. \(carbLine)"
        }
        return "\(proteinLead) \(carbLine)"
    }

    private func prioritizedFoodGroups(
        goal: Goal,
        conditions: [Condition],
        readiness: Readiness,
        hadRecentWorkout: Bool,
        activityLevel: String
    ) -> [String] {
        var items = ["Protein", "Fiber", "Vegetables", "Hydration"]
        if goal == .muscle || hadRecentWorkout || activityLevel == "active" || activityLevel == "moderate" {
            items.append("Moderate carbs")
        } else if goal == .fatLoss || conditions.contains(.pcos) {
            items.append("Moderate carbs")
        }
        if readiness.status == .low {
            items.append("Regular meals")
        }
        return Array(NSOrderedSet(array: items)) as? [String] ?? items
    }

    private func limitedFoodGroups(
        goal: Goal,
        conditions: [Condition],
        caloriesRemaining: Int,
        readiness: Readiness
    ) -> [String] {
        var items: [String] = []
        if goal == .fatLoss || caloriesRemaining < 450 {
            items.append("Large refined-carb portions")
        }
        if conditions.contains(.pcos) || conditions.contains(.diabetes) {
            items.append("Unbalanced carb-heavy meals")
        }
        if readiness.status == .low {
            items.append("Very heavy meals")
        }
        return items
    }

    private func suggestions(
        for mealType: MealType,
        context: DietGuidanceContext,
        conditions: [Condition],
        caloriesRemaining: Int,
        proteinRemaining: Int,
        aggressiveTimeline: Bool
    ) -> [MealSuggestion] {
        let history = recentSuggestionHistory(from: context.suggestionHistory, for: context.userId, upTo: context.date)
        let meals = mealLibrary().filter { item in
            guard item.mealType == mealType.rawValue else { return false }
            if context.baseline.dietPreference == .noPreference {
                return true
            }
            return item.dietTypes.contains(context.baseline.dietPreference)
        }

        let scored = meals.map { meal in
            let total = proteinFitScore(for: meal, mealType: mealType, proteinRemaining: proteinRemaining)
                + calorieFitScore(for: meal, mealType: mealType, context: context, caloriesRemaining: caloriesRemaining)
                + goalFitScore(for: meal, goal: context.goalConfig.goal, hadRecentWorkout: workoutCompleted(for: context))
                + readinessFitScore(for: meal, readiness: context.readiness)
                + conditionFitScore(for: meal, conditions: conditions)
                + activityFitScore(for: meal, context: context)
                + varietyScore(for: meal, history: history, todaysMeals: context.mealsLoggedToday)
                - repetitionPenalty(for: meal, history: history, date: context.date)
            return (meal, total)
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.proteinGrams > rhs.0.proteinGrams
            }
            return lhs.1 > rhs.1
        }

        return Array(scored.prefix(3)).map { meal, _ in
            MealSuggestion(
                name: sanitize(meal.name),
                mealType: sanitize(mealType.title),
                description: sanitize(meal.description),
                estimatedCalories: max(0, meal.calories),
                estimatedProteinGrams: max(0, meal.proteinGrams),
                estimatedCarbsGrams: max(0, meal.carbsGrams),
                estimatedFatGrams: max(0, meal.fatGrams),
                whyItFits: sanitize(whyItFits(meal: meal, mealType: mealType, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining)),
                personalizationReason: sanitize(personalizationReason(meal: meal, context: context, conditions: conditions)),
                conditionFitNote: conditionFitReason(conditions: conditions, meal: meal),
                readinessFitNote: readinessFitReason(readiness: context.readiness, meal: meal),
                targetFitNote: targetFitReason(goal: context.goalConfig.goal, hadRecentWorkout: workoutCompleted(for: context), aggressiveTimeline: aggressiveTimeline, meal: meal)
            )
        }
    }

    private func buildSupplementContextNotes(from supplements: [Supplement]) -> [String] {
        supplements
            .filter { $0.isActive }
            .filter { $0.frequency == .daily || $0.frequency == .weekly }
            .prefix(2)
            .map { supplement in
                if let time = supplement.timeOfDay {
                    return "You usually take \(supplement.name) \(time.reminderPhrase)."
                }
                return "You usually take \(supplement.name) with one of your meals."
            }
    }

    private func buildSafetyNote(for conditions: [Condition]) -> String {
        if conditions.contains(.pregnancy) {
            return "Pregnancy-specific nutrition needs should be discussed with a qualified healthcare professional."
        }
        if conditions.contains(.eatingDisorderHistory) {
            return "If food tracking feels stressful, consider using BeU without calorie targets."
        }
        if conditions.contains(.diabetes) {
            return "For diabetes-specific nutrition guidance, follow your clinician's advice."
        }
        return "BeU provides general wellness guidance only. It is not medical advice."
    }

    private func whyItFits(meal: MealLibraryItem, mealType: MealType, caloriesRemaining: Int, proteinRemaining: Int) -> String {
        if caloriesRemaining < 400 && proteinRemaining > 25 {
            return "You have \(proteinRemaining)g protein left with tighter calories remaining, so this stays efficient."
        }
        if proteinRemaining >= 40 {
            return "You still have \(proteinRemaining)g protein left, and this helps close that gap quickly."
        }
        if mealType == .snack {
            return "Useful as a smaller add-on that still contributes meaningful protein."
        }
        return "Fits the remaining day with approximate calories and protein that stay practical."
    }

    private func personalizationReason(meal: MealLibraryItem, context: DietGuidanceContext, conditions: [Condition]) -> String {
        if conditions.contains(.pcos) {
            return "High-protein vegetarian option that fits your \(context.goalConfig.goal.title.lowercased()) target and PCOS context."
        }
        if context.goalConfig.goal == .muscle && workoutCompleted(for: context) {
            return "Protein plus moderate carbs make this a stronger fit after training."
        }
        if context.readiness.status == .low {
            return "This keeps the meal balanced and easier to handle on a lower-readiness day."
        }
        return "This fits today’s goal, remaining targets, and meal timing without overcomplicating the plan."
    }

    private func conditionFitReason(conditions: [Condition], meal: MealLibraryItem) -> String? {
        if conditions.contains(.pcos) {
            return "Fits your PCOS context by prioritizing protein, fiber, and balance."
        }
        if conditions.contains(.diabetes) {
            return "Keeps the meal balanced without leaning on a heavy carb push."
        }
        if conditions.contains(.pregnancy) || conditions.contains(.eatingDisorderHistory) {
            return "Keeps the meal steady and balanced rather than restrictive."
        }
        return nil
    }

    private func readinessFitReason(readiness: Readiness, meal: MealLibraryItem) -> String? {
        switch readiness.status {
        case .low:
            return "Readiness is low, so this keeps the meal balanced and easy."
        case .limitedData:
            return "Recovery data is limited, so this suggestion leans on your goal and remaining targets."
        default:
            return nil
        }
    }

    private func targetFitReason(goal: Goal, hadRecentWorkout: Bool, aggressiveTimeline: Bool, meal: MealLibraryItem) -> String? {
        if goal == .muscle && hadRecentWorkout {
            return "Useful after training because it pairs protein with enough energy."
        }
        if goal == .fatLoss {
            if aggressiveTimeline {
                return "Supports a protein-led meal without pushing aggressive restriction."
            }
            return "Supports a protein-led meal without aggressive restriction."
        }
        return nil
    }

    private func inferredActivityLevel(from summaries: [HealthSummary], todaySteps: Int) -> String {
        let average = summaries.isEmpty
            ? Double(todaySteps)
            : Double(summaries.map(\.steps).reduce(0, +)) / Double(summaries.count)
        switch average {
        case ..<5000:
            return "sedentary"
        case ..<7500:
            return "light"
        case ..<10000:
            return "moderate"
        default:
            return "active"
        }
    }

    private func isAggressiveTimeline(goalConfig: GoalConfig, currentWeight: Int) -> Bool {
        guard let targetWeight = goalConfig.targetWeightKg else { return false }
        let months: Double
        switch goalConfig.timeline {
        case .oneMonth:
            months = 1
        case .threeMonths:
            months = 3
        case .sixMonths:
            months = 6
        case .oneYear:
            months = 12
        case .custom:
            months = Double(max(goalConfig.customYears, 1) * 12)
        }
        let monthlyChange = Double(abs(currentWeight - targetWeight)) / max(months, 1)
        switch goalConfig.goal {
        case .fatLoss:
            return monthlyChange > 2
        case .muscle:
            return monthlyChange > 1
        case .maintain, .wellness:
            return false
        }
    }

    private func sanitizedConditions(_ conditions: [Condition]) -> [Condition] {
        conditions.filter { $0 != .none && $0 != .preferNotToSay }
    }

    private func workoutCompleted(for context: DietGuidanceContext) -> Bool {
        (context.summary?.workoutCount ?? 0) > 0 || (context.recentSummaries.dropLast().last?.workoutCount ?? 0) > 0
    }

    private func recentSuggestionHistory(from allHistory: [DietSuggestionHistory], for userId: String, upTo date: String) -> [DietSuggestionHistory] {
        allHistory.filter { $0.userId == userId && $0.date <= date }
    }

    private func proteinFitScore(for meal: MealLibraryItem, mealType: MealType, proteinRemaining: Int) -> Int {
        if mealType == .snack {
            switch meal.proteinGrams {
            case 15...: return 30
            case 8...14: return 18
            default: return 8
            }
        }
        guard proteinRemaining > 0 else { return meal.tags.contains("balanced") ? 18 : 12 }
        switch meal.proteinGrams {
        case 35...: return 30
        case 25...34: return 24
        case 15...24: return 16
        default: return 8
        }
    }

    private func calorieFitScore(for meal: MealLibraryItem, mealType: MealType, context: DietGuidanceContext, caloriesRemaining: Int) -> Int {
        let budget = estimatedBudget(for: mealType, context: context, caloriesRemaining: caloriesRemaining)
        if context.goalConfig.goal == .muscle && meal.calories <= budget + 180 { return 25 }
        if meal.calories <= budget { return 25 }
        if abs(meal.calories - budget) <= 140 { return 15 }
        if meal.calories <= caloriesRemaining + 120 { return 5 }
        return 0
    }

    private func goalFitScore(for meal: MealLibraryItem, goal: Goal, hadRecentWorkout: Bool) -> Int {
        var score = meal.goalFit.contains(goal) ? 16 : 10
        if goal == .fatLoss && meal.tags.contains("low_calorie") { score += 4 }
        if goal == .muscle && (meal.tags.contains("workout_refuel") || hadRecentWorkout) { score += 4 }
        if goal == .maintain || goal == .wellness, meal.tags.contains("balanced") { score += 4 }
        return min(score, 20)
    }

    private func readinessFitScore(for meal: MealLibraryItem, readiness: Readiness) -> Int {
        switch readiness.status {
        case .low:
            return meal.tags.contains("light") || meal.tags.contains("balanced") ? 10 : 4
        case .moderate:
            return meal.tags.contains("balanced") ? 10 : 7
        case .limitedData:
            return meal.tags.contains("balanced") ? 8 : 6
        case .high, .good:
            return meal.tags.contains("calorie_dense") ? 8 : 10
        }
    }

    private func conditionFitScore(for meal: MealLibraryItem, conditions: [Condition]) -> Int {
        guard !conditions.isEmpty else { return 8 }
        var score = 0
        for condition in conditions {
            if meal.conditionsFit.contains(condition) {
                score += 5
            } else if condition == .pregnancy || condition == .eatingDisorderHistory {
                score += meal.tags.contains("balanced") ? 4 : 2
            }
        }
        return min(score, 10)
    }

    private func activityFitScore(for meal: MealLibraryItem, context: DietGuidanceContext) -> Int {
        let hadWorkout = workoutCompleted(for: context)
        if hadWorkout && meal.tags.contains("workout_refuel") {
            return 5
        }
        if context.energyBalance.remainingBurnTarget > 250 && context.energyBalance.caloriesConsumed > context.energyBalance.calorieIntakeTarget {
            return meal.tags.contains("light") ? 5 : 2
        }
        return meal.tags.contains("balanced") ? 4 : 2
    }

    private func varietyScore(for meal: MealLibraryItem, history: [DietSuggestionHistory], todaysMeals: [MealLog]) -> Int {
        let recentNames = Set(history.suffix(6).map { $0.suggestedMealName.lowercased() })
        let todaysNames = Set(todaysMeals.flatMap(\.items).map { $0.name.lowercased() })
        if recentNames.contains(meal.name.lowercased()) || todaysNames.contains(where: meal.name.lowercased().contains) {
            return 0
        }
        return 5
    }

    private func repetitionPenalty(for meal: MealLibraryItem, history: [DietSuggestionHistory], date: String) -> Int {
        let recent = history.filter { $0.suggestedMealName.caseInsensitiveCompare(meal.name) == .orderedSame }
        guard !recent.isEmpty else { return 0 }
        let currentDate = ISODateOnlyFormatter.shared.date(from: date) ?? Date()
        for entry in recent.reversed() {
            guard let entryDate = ISODateOnlyFormatter.shared.date(from: entry.date) else { continue }
            let days = Calendar.current.dateComponents([.day], from: entryDate, to: currentDate).day ?? 99
            if days == 1 { return 30 }
            if days <= 3 { return 20 }
        }
        return 10
    }

    private func estimatedBudget(for mealType: MealType, context: DietGuidanceContext, caloriesRemaining: Int) -> Int {
        let baseWeight: Double
        switch mealType {
        case .breakfast: baseWeight = 0.25
        case .lunch: baseWeight = 0.35
        case .dinner: baseWeight = 0.30
        case .snack: baseWeight = 0.10
        }

        let loggedTypes = Set(context.mealsLoggedToday.map(\.mealType))
        let unlogged = MealType.allCases.filter { !loggedTypes.contains($0) }
        if context.mealsLoggedToday.isEmpty || unlogged.isEmpty {
            return max(180, Int((Double(context.calorieTarget) * baseWeight).rounded()))
        }

        let remainingWeight = unlogged.reduce(0.0) { partial, type in
            partial + mealWeight(for: type)
        }
        let normalizedWeight = mealWeight(for: mealType) / max(remainingWeight, 0.1)
        return max(160, Int((Double(caloriesRemaining) * normalizedWeight).rounded()))
    }

    private func mealWeight(for mealType: MealType) -> Double {
        switch mealType {
        case .breakfast: return 0.25
        case .lunch: return 0.35
        case .dinner: return 0.30
        case .snack: return 0.10
        }
    }

    private func mealLibrary() -> [MealLibraryItem] {
        [
            meal("Moong dal chilla with curd", .breakfast, 360, 24, 38, 10, ["high_protein", "balanced", "breakfast_friendly", "indian_vegetarian"], [.indianVegetarian, .vegetarian], [.pcos, .diabetes], [.fatLoss, .maintain, .wellness], "Moong dal chilla with curd and chutney."),
            meal("Besan chilla with paneer filling", .breakfast, 390, 26, 32, 14, ["high_protein", "balanced", "breakfast_friendly"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .muscle], "Besan chilla filled with paneer and vegetables."),
            meal("Sprouts chaat bowl", .breakfast, 280, 18, 34, 7, ["high_fiber", "light", "vegan", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Sprouts, vegetables, herbs, and lemon."),
            meal("Hung curd oats bowl", .breakfast, 320, 20, 36, 8, ["balanced", "quick", "breakfast_friendly"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .maintain], "Hung curd with oats, seeds, and fruit."),
            meal("Oats upma with curd", .breakfast, 340, 16, 42, 9, ["balanced", "high_fiber", "breakfast_friendly"], [.indianVegetarian, .vegetarian], [.pcos], [.maintain, .wellness], "Savory oats upma with a side of curd."),
            meal("Tofu scramble with toast", .breakfast, 350, 27, 28, 12, ["high_protein", "vegan", "quick", "breakfast_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .muscle], "Tofu scramble with vegetables and toast."),
            meal("Idli sambar", .breakfast, 330, 13, 50, 6, ["balanced", "light", "breakfast_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.maintain, .wellness], "Idli with sambar and chutney."),
            meal("Dal dosa with chutney", .breakfast, 370, 19, 44, 9, ["balanced", "high_fiber", "breakfast_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .maintain], "Fermented dal dosa with chutney."),
            meal("Poha with sprouts", .breakfast, 310, 14, 44, 7, ["balanced", "quick", "breakfast_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.wellness, .maintain], "Poha with added sprouts for protein."),
            meal("Protein smoothie", .breakfast, 300, 25, 28, 8, ["high_protein", "quick", "light"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.muscle, .fatLoss], "Smoothie with protein, fruit, and milk or plant milk."),

            meal("Dal roti curd salad", .lunch, 520, 26, 62, 12, ["balanced", "high_fiber", "indian_vegetarian"], [.indianVegetarian, .vegetarian], [.pcos, .diabetes], [.fatLoss, .maintain, .wellness], "Dal, roti, curd, and a salad side."),
            meal("Rajma bowl with curd and salad", .lunch, 610, 28, 78, 14, ["balanced", "workout_refuel"], [.indianVegetarian, .vegetarian], [.pcos], [.muscle, .maintain], "Rajma, rice, curd, and salad."),
            meal("Chole salad bowl", .lunch, 480, 22, 50, 14, ["balanced", "high_fiber", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Chole with salad vegetables and herbs."),
            meal("Paneer bhurji with roti", .lunch, 560, 34, 32, 24, ["high_protein", "balanced"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .muscle], "Paneer bhurji with roti and vegetables."),
            meal("Tofu bhurji bowl", .lunch, 510, 32, 34, 18, ["high_protein", "balanced", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .muscle], "Tofu bhurji with vegetables and grains."),
            meal("Soya curry with roti", .lunch, 530, 38, 40, 15, ["high_protein", "balanced", "indian_vegetarian"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .muscle], "Soya curry, roti, and salad."),
            meal("Khichdi with curd", .lunch, 470, 18, 64, 11, ["balanced", "light"], [.indianVegetarian, .vegetarian], [.pregnancy], [.wellness, .maintain], "Khichdi with curd and vegetables."),
            meal("Tofu bowl with quinoa", .lunch, 560, 30, 58, 16, ["high_protein", "balanced", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .muscle], "Tofu, quinoa, vegetables, and herbs."),
            meal("Sambar rice with salad", .lunch, 500, 17, 72, 9, ["balanced"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.maintain, .wellness], "Rice with sambar and salad."),
            meal("Chickpea quinoa bowl", .lunch, 540, 24, 60, 15, ["balanced", "high_fiber", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .maintain], "Chickpeas, quinoa, and vegetables."),

            meal("Tofu stir fry bowl", .dinner, 430, 30, 28, 16, ["high_protein", "light", "dinner_friendly", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .maintain], "Tofu stir fry with vegetables."),
            meal("Paneer stir fry bowl", .dinner, 470, 31, 24, 22, ["high_protein", "balanced", "dinner_friendly"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .muscle], "Paneer stir fry with vegetables."),
            meal("Dal soup with tofu salad", .dinner, 420, 30, 34, 12, ["high_protein", "light", "dinner_friendly", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Dal soup with a tofu salad side."),
            meal("Khichdi dinner bowl", .dinner, 440, 16, 58, 10, ["balanced", "light", "dinner_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.wellness, .maintain], "Khichdi with vegetables."),
            meal("Soya pulao", .dinner, 560, 35, 58, 14, ["high_protein", "workout_refuel", "dinner_friendly", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.muscle, .maintain], "Soya pulao with vegetables."),
            meal("Mixed dal dosa", .dinner, 390, 18, 42, 9, ["balanced", "dinner_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Mixed dal dosa with chutney."),
            meal("Vegetable dalia", .dinner, 360, 14, 48, 8, ["light", "balanced", "dinner_friendly"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.fatLoss, .wellness], "Vegetable dalia bowl."),
            meal("Paneer tikka bowl", .dinner, 500, 34, 26, 20, ["high_protein", "balanced", "dinner_friendly"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .muscle], "Paneer tikka bowl with vegetables."),
            meal("Tofu curry with roti", .dinner, 480, 29, 38, 15, ["high_protein", "balanced", "dinner_friendly", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .maintain], "Tofu curry with roti and vegetables."),
            meal("Sprouts bowl", .dinner, 340, 20, 36, 9, ["high_fiber", "light", "dinner_friendly", "vegan"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Sprouts bowl with chopped vegetables."),

            meal("Roasted chana", .snack, 180, 9, 22, 5, ["quick", "vegan", "light"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Roasted chana snack."),
            meal("Hung curd bowl", .snack, 210, 18, 16, 8, ["high_protein", "light", "quick"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .maintain], "Hung curd with seeds and fruit."),
            meal("Tofu cubes with chutney", .snack, 220, 20, 8, 12, ["high_protein", "vegan", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .muscle], "Tofu cubes with herbs or chutney."),
            meal("Paneer cubes", .snack, 240, 19, 6, 14, ["high_protein", "quick"], [.indianVegetarian, .vegetarian], [.pcos], [.fatLoss, .muscle], "Paneer cubes with seasoning."),
            meal("Sprouts chaat", .snack, 190, 14, 24, 4, ["high_fiber", "vegan", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Sprouts chaat with onion and tomato."),
            meal("Protein shake", .snack, 230, 24, 14, 6, ["high_protein", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.muscle, .fatLoss], "Protein shake with milk or plant milk."),
            meal("Makhana", .snack, 170, 6, 18, 7, ["light", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pregnancy], [.wellness, .maintain], "Roasted makhana."),
            meal("Peanuts small portion", .snack, 200, 8, 8, 15, ["quick", "calorie_dense"], [.indianVegetarian, .vegetarian, .vegan], [], [.muscle, .maintain], "Small roasted peanuts portion."),
            meal("Fruit with curd", .snack, 210, 12, 24, 6, ["balanced", "quick"], [.indianVegetarian, .vegetarian], [.pregnancy], [.maintain, .wellness], "Fruit with curd."),
            meal("Boiled chana cup", .snack, 190, 10, 26, 3, ["high_fiber", "vegan", "quick"], [.indianVegetarian, .vegetarian, .vegan], [.pcos], [.fatLoss, .wellness], "Boiled chana with seasoning."),
        ]
    }

    private func meal(
        _ name: String,
        _ mealType: MealType,
        _ calories: Int,
        _ protein: Int,
        _ carbs: Int,
        _ fat: Int,
        _ tags: [String],
        _ dietTypes: [DietPreference],
        _ conditionsFit: [Condition],
        _ goalFit: [Goal],
        _ description: String
    ) -> MealLibraryItem {
        MealLibraryItem(
            name: name,
            mealType: mealType.rawValue,
            description: description,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            tags: tags,
            dietTypes: dietTypes,
            conditionsFit: conditionsFit,
            goalFit: goalFit
        )
    }

    private func sanitize(_ text: String) -> String {
        var candidate = LanguageGuard.sanitized(text)
        for forbidden in forbiddenMedicalLanguage {
            candidate = candidate.replacingOccurrences(of: forbidden, with: "", options: .caseInsensitive)
        }
        return candidate.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitize(_ suggestion: MealSuggestion) -> MealSuggestion {
        MealSuggestion(
            name: sanitize(suggestion.name),
            mealType: sanitize(suggestion.mealType),
            description: sanitize(suggestion.description),
            estimatedCalories: suggestion.estimatedCalories,
            estimatedProteinGrams: suggestion.estimatedProteinGrams,
            estimatedCarbsGrams: suggestion.estimatedCarbsGrams,
            estimatedFatGrams: suggestion.estimatedFatGrams,
            whyItFits: sanitize(suggestion.whyItFits),
            personalizationReason: sanitize(suggestion.personalizationReason),
            conditionFitNote: suggestion.conditionFitNote.map(sanitize),
            readinessFitNote: suggestion.readinessFitNote.map(sanitize),
            targetFitNote: suggestion.targetFitNote.map(sanitize)
        )
    }

    private func sanitize(_ grouped: MealSuggestionsByType) -> MealSuggestionsByType {
        MealSuggestionsByType(
            breakfast: grouped.breakfast.map(sanitize),
            lunch: grouped.lunch.map(sanitize),
            dinner: grouped.dinner.map(sanitize),
            snacks: grouped.snacks.map(sanitize)
        )
    }
}

final class PlanService {
    private let apiClient: APIClient
    private let dietGuidanceService: DietGuidanceService
    private let adaptivePlanService: AdaptivePlanService
    private let mealLogService: MealLogService
    private let suggestionHistoryService: DietSuggestionHistoryService
    private let supplementIntakeLogRepository: SupplementIntakeLogRepository

    init(
        apiClient: APIClient = APIClient(),
        dietGuidanceService: DietGuidanceService = DietGuidanceService(),
        mealLogService: MealLogService = MealLogService(),
        suggestionHistoryService: DietSuggestionHistoryService = DietSuggestionHistoryService(),
        adaptivePlanService: AdaptivePlanService = AdaptivePlanService(),
        supplementIntakeLogRepository: SupplementIntakeLogRepository = SupplementIntakeLogRepository()
    ) {
        self.apiClient = apiClient
        self.dietGuidanceService = dietGuidanceService
        self.mealLogService = mealLogService
        self.suggestionHistoryService = suggestionHistoryService
        self.adaptivePlanService = adaptivePlanService
        self.supplementIntakeLogRepository = supplementIntakeLogRepository
    }

    func fetchTodayPlan(userId: String) async throws -> DailyPersonalizedActionPlan {
        try await apiClient.fetchTodayPlan(userId: userId)
    }

    func fetchWeeklyPlan(userId: String) async throws -> WeeklyPersonalizedActionPlan {
        try await apiClient.fetchWeeklyPlan(userId: userId)
    }

    func fetchWeeklyInsights(userId: String) async throws -> WeeklyInsightsResponse {
        try await apiClient.fetchWeeklyInsights(userId: userId)
    }

    func logWater(userId: String, litres: Double) async throws -> LogWaterResponse {
        try await apiClient.logWater(userId: userId, litres: litres)
    }

    func fallbackDailyPlan(
        userId: String,
        readiness: ReadinessCardModel,
        card: DailyPlanCardModel,
        progress: DailyNutritionProgress?,
        summary: HealthSummary?
    ) -> DailyPersonalizedActionPlan {
        let calories = progress?.calorieTarget ?? 0
        let protein = progress?.proteinTargetGrams ?? 0
        let stepsTarget = max(7000, (summary?.steps ?? 0) + 1000)
        return DailyPersonalizedActionPlan(
            userId: userId,
            date: ISO8601DateFormatter().string(from: Date()).prefix(10).description,
            onboardingRequired: false,
            targets: DailyPersonalizedActionPlanTargets(
                calories: calories,
                proteinGrams: protein,
                waterLiters: card.hydrationLiters,
                steps: stepsTarget,
                cardioMinutes: stepsTarget > 8000 ? 25 : 20,
                strengthTraining: EngineStrengthTrainingPlan(
                    recommendation: readiness.status.lowercased() == "low" ? .rest : .optional,
                    durationMinutes: readiness.status.lowercased() == "low" ? 20 : 30,
                    intensity: readiness.status.lowercased() == "high" ? .high : .moderate,
                    focus: readiness.status.lowercased() == "low" ? "recovery" : "full_body"
                )
            ),
            progress: DailyPersonalizedActionPlanProgress(
                caloriesConsumed: progress?.consumedCalories ?? 0,
                caloriesRemaining: progress?.remainingCalories ?? 0,
                proteinConsumedGrams: progress?.consumedProteinGrams ?? 0,
                proteinRemainingGrams: progress?.remainingProteinGrams ?? 0,
                stepsCompleted: summary?.steps ?? 0,
                stepsRemaining: max(0, stepsTarget - (summary?.steps ?? 0)),
                waterConsumedLiters: 0,
                waterRemainingLiters: card.hydrationLiters
            ),
            planSummary: readiness.status.lowercased() == "low"
                ? "Today is a recovery-focused day. Prioritize protein, hydration, and light movement."
                : readiness.status.lowercased() == "limited_data"
                    ? "Some recovery data is still syncing, so today’s plan uses your goal and activity progress."
                : "Keep the day balanced with steady meals, fluids, and practical movement.",
            priorityActions: Array(card.priorityActions.prefix(4).enumerated()).map { index, action in
                DailyPersonalizedPriorityAction(
                    title: action,
                    description: action,
                    priority: index == 0 ? .high : .medium,
                    category: index == 0 && readiness.status.lowercased() == "low" ? .recovery : .nutrition
                )
            },
            realTimeNudges: [],
            supplementReminders: card.supplementReminders,
            healthContextNotes: card.healthContextNotes,
            explanation: card.explanation,
            safetyNote: card.safetyNote ?? BeUSafetyCopy.wellnessDisclaimer,
            carbGuidance: card.carbAdjustment,
            calorieDirection: card.calorieDirection,
            proteinLevel: card.proteinTarget
        )
    }

    func fallbackWeeklyPlan(from dailyPlan: DailyPersonalizedActionPlan, trend: ReadinessTrendSummary) -> WeeklyPersonalizedActionPlan {
        WeeklyPersonalizedActionPlan(
            userId: dailyPlan.userId,
            weekStartDate: trend.points.first?.date ?? dailyPlan.date,
            weekEndDate: trend.points.last?.date ?? dailyPlan.date,
            onboardingRequired: false,
            weeklyTargets: WeeklyPersonalizedActionPlanTargets(
                avgDailyCalories: dailyPlan.targets.calories,
                avgDailyProteinGrams: dailyPlan.targets.proteinGrams,
                totalStrengthSessions: dailyPlan.targets.strengthTraining.recommendation == .required ? 4 : 2,
                totalCardioMinutes: dailyPlan.targets.cardioMinutes * 5,
                avgDailySteps: dailyPlan.targets.steps,
                avgDailyWaterLiters: dailyPlan.targets.waterLiters
            ),
            weeklyFocus: [
                "Keep meals simple and repeatable.",
                "Use a movement target that feels reachable each day.",
                "Let recovery shape the harder days."
            ],
            weeklyFeedback: WeeklyPersonalizedActionPlanFeedback(
                readinessTrend: trend.trendDirection,
                calorieConsistency: "steady",
                proteinConsistency: "consistent",
                activityConsistency: "consistent",
                recoveryConsistency: trend.summaryMessage
            ),
            recommendedAdjustments: [
                WeeklyRecommendedAdjustment(title: "Stay consistent", description: "Keep following the basics that already work.", reason: "The plan is using limited local data."),
                WeeklyRecommendedAdjustment(title: "Protect recovery", description: "If readiness dips, reduce training demand first.", reason: "Recovery should shape harder days."),
                WeeklyRecommendedAdjustment(title: "Keep protein steady", description: "A repeatable protein-first meal helps most days feel easier.", reason: "Protein consistency supports the weekly plan.")
            ],
            explanation: [
                "Weekly targets are estimated from your current daily targets and recent readiness trend."
            ],
            safetyNote: BeUSafetyCopy.wellnessDisclaimer
        )
    }

    func fallbackWeeklyInsights(from trend: ReadinessTrendSummary, consistency: ConsistencyCardModel) -> WeeklyInsightsResponse {
        WeeklyInsightsResponse(
            userId: "demo-user",
            weekStartDate: trend.points.first?.date ?? "",
            weekEndDate: trend.points.last?.date ?? "",
            averageReadiness: trend.averageScore,
            consistencyScore: consistency.weeklyConsistencyScore,
            trendDirection: trend.trendDirection,
            cards: [
                WeeklyInsightCard(kicker: "READINESS", sentence: trend.summaryMessage),
                WeeklyInsightCard(kicker: "CONSISTENCY", sentence: consistency.message),
                WeeklyInsightCard(kicker: "NEXT", sentence: "Use meals, water, and manageable movement to keep the week steady.")
            ],
            actions: [
                WeeklyInsightAction(title: "Stay steady", description: "Keep the next week simple and repeatable."),
                WeeklyInsightAction(title: "Lead with protein", description: "Use one protein-forward meal as an anchor."),
                WeeklyInsightAction(title: "Protect sleep", description: "Recovery gets easier when sleep stays more consistent.")
            ],
            disclaimer: BeUSafetyCopy.wellnessDisclaimer
        )
    }

    func calcTargets(goal: Goal, weightKg: Int, heightCm: Int, age: Int, gender: Gender) -> (kcal: Int, protein: Int) {
        let s: Int
        switch gender {
        case .male:
            s = 5
        case .female:
            s = -161
        case .nonBinary:
            s = -78
        }
        let bmr = 10 * Double(weightKg) + 6.25 * Double(heightCm) - 5 * Double(age) + Double(s)
        let tdee = bmr * 1.45
        let adjustment: Double = goal == .fatLoss ? -450 : (goal == .muscle ? 280 : 0)
        let kcal = Int(((tdee + adjustment) / 10).rounded()) * 10
        let proteinPerKg: Double = goal == .muscle ? 2.0 : (goal == .fatLoss ? 1.8 : 1.4)
        return (kcal, Int(Double(weightKg) * proteinPerKg))
    }

    func buildPlan(
        userId: String,
        baseline: Baseline,
        goalConfig: GoalConfig,
        intake: DailyIntake,
        readiness: Readiness,
        signals: HealthSignals,
        summary: HealthSummary?,
        recentSummaries: [HealthSummary]
    ) -> DailyPlan {
        var targetPair = calcTargets(
            goal: goalConfig.goal,
            weightKg: baseline.weightKg,
            heightCm: baseline.heightCm,
            age: baseline.age,
            gender: baseline.gender
        )

        let preset = GoalPresets[goalConfig.goal] ?? GoalPresets[.wellness]!
        var waterTarget = preset.waterLitres
        if !readiness.usedDefaultSleep && signals.sleepHours < signals.sleepTarget - 0.5 {
            waterTarget += 0.1
        }

        let isPregnancy = baseline.medical.contains(.pregnancy)
        let hasEDHistory = baseline.medical.contains(.eatingDisorderHistory)
        let hasDiabetes = baseline.medical.contains(.diabetes)

        var calorieDirection = preset.direction
        var carbGuidance = preset.carbGuidance
        var proteinLevel = goalConfig.goal == .muscle || goalConfig.goal == .fatLoss ? "High protein" : "Moderate protein"

        if readiness.status == .low || isPregnancy || hasEDHistory {
            calorieDirection = "Consistency"
        }
        if hasDiabetes {
            carbGuidance = "balanced carbs"
        }
        if hasEDHistory {
            proteinLevel = "Regular meals"
        }

        if isPregnancy {
            targetPair.kcal = max(targetPair.kcal, GoalPresets[.maintain]?.kcal ?? targetPair.kcal)
        }

        let estimatedBMR = calculateBMR(
            weightKg: baseline.weightKg,
            heightCm: baseline.heightCm,
            age: baseline.age,
            gender: baseline.gender
        )
        let sevenDayAverageSteps = recentSummaries.isEmpty
            ? Double(summary?.steps ?? intake.steps)
            : Double(recentSummaries.map(\.steps).reduce(0, +)) / Double(recentSummaries.count)
        let activityMultiplier = inferredActivityMultiplier(from: sevenDayAverageSteps)
        let dailyBurnTarget = Int((Double(estimatedBMR) * activityMultiplier).rounded())
        let activeEnergyBurned = Int((summary?.activeEnergyKcal ?? 0).rounded())
        let basalEnergyBurned = summary?.basalEnergyKcal.map { Int($0.rounded()) }
        let workoutEnergyBurned = Int((summary?.workoutEnergyKcal ?? 0).rounded())
        let estimatedTotalBurn = Int(((summary?.basalEnergyKcal ?? Double(estimatedBMR)) + (summary?.activeEnergyKcal ?? 0)).rounded())
        let remainingBurnTarget = max(0, dailyBurnTarget - estimatedTotalBurn)
        let energyBalance = buildEnergyBalance(
            date: summary?.date ?? ISODateOnlyFormatter.shared.string(from: Date()),
            calorieTarget: targetPair.kcal,
            caloriesConsumed: intake.kcal,
            activeEnergyBurned: activeEnergyBurned,
            basalEnergyBurned: basalEnergyBurned,
            workoutEnergyBurned: workoutEnergyBurned,
            estimatedTotalBurn: estimatedTotalBurn,
            dailyBurnTarget: dailyBurnTarget
        )

        let baseSteps: Int
        switch goalConfig.goal {
        case .fatLoss:
            baseSteps = 7100
        case .muscle:
            baseSteps = 7600
        case .maintain:
            baseSteps = 7500
        case .wellness:
            baseSteps = 7200
        }

        let cardioStepsTarget: Int
        let strength: PlanStrengthRecommendation
        let cardioMessage: String

        if readiness.status == .low {
            cardioStepsTarget = Int((Double(baseSteps) * 0.85).rounded())
            strength = PlanStrengthRecommendation(kind: .rest, durationMinutes: 0, intensity: "Rest day")
            cardioMessage = remainingBurnTarget > 250
                ? "Recovery is low, so keep movement light instead of chasing burn."
                : "Keep movement light today."
        } else if readiness.status == .limitedData {
            cardioStepsTarget = remainingBurnTarget <= 0 ? max(summary?.steps ?? intake.steps, baseSteps - 400) : baseSteps
            strength = PlanStrengthRecommendation(kind: .optional, durationMinutes: 30, intensity: "Light")
            cardioMessage = "Some recovery data is still syncing, so keep activity balanced and follow your normal plan."
        } else if goalConfig.goal == .muscle {
            cardioStepsTarget = remainingBurnTarget <= 0 ? max(summary?.steps ?? intake.steps, baseSteps - 600) : baseSteps
            strength = PlanStrengthRecommendation(kind: .required, durationMinutes: 45, intensity: readiness.status == .high ? "Moderate" : "Light")
            cardioMessage = workoutEnergyBurned > 250
                ? "Workout burn is already strong today. Extra cardio is optional."
                : "Keep steps reasonable and let training lead the day."
        } else {
            cardioStepsTarget = remainingBurnTarget <= 0
                ? max(summary?.steps ?? intake.steps, baseSteps - 400)
                : ((readiness.status == .high || readiness.status == .good) && goalConfig.goal == .fatLoss ? baseSteps + 400 : baseSteps)
            strength = PlanStrengthRecommendation(kind: .optional, durationMinutes: 30, intensity: readiness.status == .high ? "Moderate" : "Light")
            if remainingBurnTarget > 250 {
                cardioMessage = "A walk is the easiest way to close today's burn gap."
            } else {
                cardioMessage = "You're on track. Extra steps are optional."
            }
        }

        let supplementReminders = buildSupplementReminders(from: baseline.supplements)
        let healthContextNote = healthContextNote(for: baseline.medical)
        let safetyNote = safetyNote(for: baseline.medical)
        let planDate = summary?.date ?? ISODateOnlyFormatter.shared.string(from: Date())
        let mealsLoggedToday = mealLogService.mealLogs(for: userId, date: planDate)
        let suggestionHistory = suggestionHistoryService.histories(for: userId)
        let supplementLogs = supplementIntakeLogRepository.getLogs(userId: userId, date: planDate)
        let activeConditions = baseline.medical.filter { $0 != .none && $0 != .preferNotToSay }
        let dietGuidance = dietGuidanceService.buildGuidance(
            from: DietGuidanceContext(
                userId: userId,
                date: planDate,
                dayOfWeek: MealLog.dayOfWeekString(from: planDate),
                baseline: baseline,
                goalConfig: goalConfig,
                intake: intake,
                readiness: readiness,
                signals: signals,
                summary: summary,
                recentSummaries: recentSummaries,
                mealsLoggedToday: mealsLoggedToday,
                suggestionHistory: suggestionHistory,
                energyBalance: energyBalance,
                calorieTarget: targetPair.kcal,
                proteinTarget: targetPair.protein,
                waterTarget: waterTarget,
                stepTarget: cardioStepsTarget
            )
        )
        let adaptivePlan = adaptivePlanService.build(
            input: AdaptivePlanInput(
                userId: userId,
                date: planDate,
                goal: .init(
                    goalType: adaptiveGoalType(goalConfig.goal),
                    targetWeightKg: goalConfig.targetWeightKg.map(Double.init),
                    timelineWeeks: timelineWeeks(for: goalConfig)
                ),
                baseTargets: .init(
                    calorieTarget: targetPair.kcal,
                    proteinTargetGrams: targetPair.protein,
                    stepTarget: cardioStepsTarget,
                    waterTargetLiters: ((waterTarget * 10).rounded()) / 10,
                    burnTargetKcal: energyBalance.dailyBurnTarget
                ),
                progress: .init(
                    caloriesConsumed: intake.kcal,
                    proteinConsumedGrams: Double(intake.protein),
                    carbsConsumedGrams: Double(intake.carbs),
                    fatConsumedGrams: Double(intake.fat),
                    stepsCompleted: summary?.steps ?? intake.steps,
                    activeEnergyBurnedKcal: summary.map { Int($0.activeEnergyKcal.rounded()) },
                    estimatedTotalBurnKcal: energyBalance.estimatedTotalBurn,
                    workoutEnergyBurnedKcal: energyBalance.workoutEnergyBurned,
                    waterConsumedLiters: intake.waterLitres
                ),
                readiness: .init(
                    score: readiness.score,
                    status: adaptiveReadinessStatus(readiness.status),
                    usedDefaultSleep: readiness.usedDefaultSleep
                ),
                historicalPerformance: .init(
                    sevenDayAvgSteps: average(recentSummaries.map(\.steps)),
                    sevenDayAvgActiveEnergyKcal: average(recentSummaries.map { Int($0.activeEnergyKcal.rounded()) }),
                    proteinTargetHitDaysLast7: proteinTargetHitDays(recentSummaries: recentSummaries, userId: userId, proteinTarget: targetPair.protein),
                    stepTargetHitDaysLast7: recentSummaries.filter { $0.steps >= cardioStepsTarget }.count,
                    calorieTargetHitDaysLast7: calorieTargetHitDays(recentSummaries: recentSummaries, userId: userId, calorieTarget: targetPair.kcal),
                    readinessTrend: readinessTrendLabel(recentSummaries: recentSummaries),
                    strengthSessionsLast7Days: recentSummaries.filter { $0.workoutCount > 0 || $0.workoutMinutes >= 20 }.count
                ),
                todayContext: .init(
                    currentHour: Calendar.current.component(.hour, from: Date()),
                    mealsLoggedToday: mealsLoggedToday.count,
                    workoutToday: (summary?.workoutCount ?? 0) > 0 || Int((summary?.workoutEnergyKcal ?? 0).rounded()) >= 100,
                    workoutYesterday: workoutYesterday(recentSummaries: recentSummaries, todayDate: planDate),
                    supplementsDue: adaptiveSupplementReminders(
                        supplements: baseline.supplements,
                        logs: supplementLogs,
                        date: planDate
                    ),
                    healthConditions: activeConditions.map { $0.title }
                )
            )
        )

        var explanation = [
            "Calories and protein are estimated from your baseline profile and current goal.",
            "Water stays anchored to your goal and today’s recovery context.",
            "Activity shifts with readiness, so lower-readiness days protect recovery first.",
            "Apple Health active energy shapes daily burn progress, while workout calories are shown separately for context.",
            "Estimated total burn uses basal energy when Apple Health provides it, otherwise BeU falls back to BMR plus active energy.",
        ]

        if baseline.medical.contains(.pcos) {
            explanation.append("PCOS is in your baseline, so the plan favors balanced meals, protein, and consistency.")
        }
        if isPregnancy {
            explanation.append("Pregnancy is in your baseline, so the plan avoids deficit framing.")
        }
        if hasEDHistory {
            explanation.append("Eating disorder history is in your baseline, so the plan avoids weight-loss pressure.")
        }

        if workoutEnergyBurned > 0 {
            explanation.append("Workout calories are shown separately for context and are not double-counted on top of active energy.")
        }

        if energyBalance.remainingBurnTarget <= 0 {
            explanation.append("Today's estimated burn is already on track, so extra cardio pressure stays low.")
        } else if readiness.status == .low {
            explanation.append("Readiness is low, so BeU does not push aggressive burn targets today.")
        } else if readiness.status == .limitedData {
            explanation.append("Some recovery data is still syncing, so BeU is using your goal and daily progress for the plan.")
        }

        return DailyPlan(
            kcalTarget: targetPair.kcal,
            proteinTarget: targetPair.protein,
            waterLitresTarget: ((waterTarget * 10).rounded()) / 10,
            carbGuidance: LanguageGuard.sanitized(carbGuidance),
            calorieDirection: LanguageGuard.sanitized(calorieDirection),
            proteinLevel: LanguageGuard.sanitized(proteinLevel),
            strength: strength,
            cardioStepsTarget: cardioStepsTarget,
            cardioMessage: LanguageGuard.sanitized(cardioMessage),
            energyBalance: energyBalance,
            adaptivePlan: adaptivePlan,
            dietGuidance: dietGuidance,
            supplementReminders: supplementReminders,
            healthContextNote: healthContextNote,
            safetyNote: safetyNote,
            explanation: LanguageGuard.sanitized(explanation)
        )
    }

    private func buildEnergyBalance(
        date: String,
        calorieTarget: Int,
        caloriesConsumed: Int,
        activeEnergyBurned: Int,
        basalEnergyBurned: Int?,
        workoutEnergyBurned: Int,
        estimatedTotalBurn: Int,
        dailyBurnTarget: Int
    ) -> DailyEnergyBalance {
        let remainingBurnTarget = max(0, dailyBurnTarget - estimatedTotalBurn)
        let targetNetCalories = calorieTarget - dailyBurnTarget
        let netCalories = caloriesConsumed - estimatedTotalBurn
        let status: String
        let message: String

        if caloriesConsumed > calorieTarget && remainingBurnTarget > 150 {
            status = "over_consumed"
            message = "Calories are above target and activity is behind."
        } else if remainingBurnTarget <= 0 {
            status = caloriesConsumed <= calorieTarget ? "balanced" : "on_track"
            message = "Burn target met. Extra movement is optional."
        } else if remainingBurnTarget > 250 {
            status = "under_burned"
            message = "Activity is behind today's burn target."
        } else {
            status = "on_track"
            message = "Nutrition and activity are moving in the right direction."
        }

        return DailyEnergyBalance(
            date: date,
            calorieIntakeTarget: calorieTarget,
            caloriesConsumed: caloriesConsumed,
            activeEnergyBurned: activeEnergyBurned,
            basalEnergyBurned: basalEnergyBurned,
            workoutEnergyBurned: workoutEnergyBurned,
            estimatedTotalBurn: estimatedTotalBurn,
            dailyBurnTarget: dailyBurnTarget,
            remainingBurnTarget: remainingBurnTarget,
            netCalories: netCalories,
            targetNetCalories: targetNetCalories,
            energyBalanceStatus: status,
            message: LanguageGuard.sanitized(message)
        )
    }

    private func adaptiveGoalType(_ goal: Goal) -> String {
        switch goal {
        case .fatLoss: return "fat_loss"
        case .muscle: return "muscle_gain"
        case .maintain: return "maintain"
        case .wellness: return "general_wellness"
        }
    }

    private func adaptiveReadinessStatus(_ status: ReadinessStatus) -> String {
        switch status {
        case .high: return "high"
        case .good: return "good"
        case .moderate: return "moderate"
        case .low: return "low"
        case .limitedData: return "limited_data"
        }
    }

    private func timelineWeeks(for config: GoalConfig) -> Int? {
        switch config.timeline {
        case .oneMonth: return 4
        case .threeMonths: return 12
        case .sixMonths: return 24
        case .oneYear: return 52
        case .custom: return max(config.customYears, 1) * 52
        }
    }

    private func average(_ values: [Int]) -> Int? {
        guard values.isEmpty == false else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private func proteinTargetHitDays(recentSummaries: [HealthSummary], userId: String, proteinTarget: Int) -> Int {
        recentSummaries.reduce(into: 0) { count, summary in
            let dayMeals = mealLogService.mealLogs(for: userId, date: summary.date)
            let protein = dayMeals.reduce(0.0) { $0 + $1.totalProteinGrams }
            if protein >= Double(proteinTarget) {
                count += 1
            }
        }
    }

    private func calorieTargetHitDays(recentSummaries: [HealthSummary], userId: String, calorieTarget: Int) -> Int {
        recentSummaries.reduce(into: 0) { count, summary in
            let dayMeals = mealLogService.mealLogs(for: userId, date: summary.date)
            let calories = dayMeals.reduce(0) { $0 + $1.totalCalories }
            if calories <= calorieTarget {
                count += 1
            }
        }
    }

    private func readinessTrendLabel(recentSummaries: [HealthSummary]) -> String? {
        guard recentSummaries.count >= 4 else { return "stable" }
        let ordered = recentSummaries.sorted { $0.date < $1.date }
        let firstHalf = ordered.prefix(ordered.count / 2).map(\.sleepHours)
        let secondHalf = ordered.suffix(ordered.count / 2).map(\.sleepHours)
        let firstAvg = firstHalf.reduce(0, +) / Double(max(firstHalf.count, 1))
        let secondAvg = secondHalf.reduce(0, +) / Double(max(secondHalf.count, 1))
        if secondAvg - firstAvg > 0.3 { return "improving" }
        if firstAvg - secondAvg > 0.3 { return "declining" }
        return "stable"
    }

    private func workoutYesterday(recentSummaries: [HealthSummary], todayDate: String) -> Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: ISODateOnlyFormatter.shared.date(from: todayDate) ?? Date())
        let key = yesterday.map { ISODateOnlyFormatter.shared.string(from: $0) }
        guard let key else { return false }
        guard let summary = recentSummaries.first(where: { $0.date == key }) else { return false }
        return summary.workoutCount > 0 || Int(summary.workoutEnergyKcal.rounded()) >= 100
    }

    private func adaptiveSupplementReminders(supplements: [Supplement], logs: [SupplementIntakeLog], date: String) -> [AdaptiveSupplementReminder] {
        supplements.filter(\.isActive).map { supplement in
            let taken = logs.contains { $0.supplementId == supplement.id && $0.date == date && $0.status == "taken" }
            return AdaptiveSupplementReminder(
                id: supplement.id,
                supplementId: supplement.id,
                name: supplement.name,
                timing: supplement.timeOfDay?.title,
                status: taken ? "taken" : dueStatus(for: supplement.timeOfDay)
            )
        }
    }

    private func dueStatus(for time: SupplementTime?) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch time {
        case .morning? where hour >= 12:
            return "due_today"
        case .afternoon? where hour >= 17:
            return "due_today"
        case .evening?, .beforeBed?:
            return hour < 17 ? "due_later" : "due_today"
        default:
            return "due_today"
        }
    }


    private func calculateBMR(weightKg: Int, heightCm: Int, age: Int, gender: Gender) -> Int {
        let s: Int
        switch gender {
        case .male:
            s = 5
        case .female:
            s = -161
        case .nonBinary:
            s = -78
        }
        let bmr = 10 * Double(weightKg) + 6.25 * Double(heightCm) - 5 * Double(age) + Double(s)
        return Int(bmr.rounded())
    }

    private func inferredActivityMultiplier(from averageSteps: Double) -> Double {
        switch averageSteps {
        case ..<5000:
            return 1.2
        case ..<7500:
            return 1.375
        case ..<10000:
            return 1.55
        default:
            return 1.725
        }
    }

    private func buildSupplementReminders(from supplements: [Supplement]) -> [String] {
        let currentBand = currentTimeBand()
        return supplements
            .filter { $0.isActive }
            .filter { $0.frequency == .daily || $0.frequency == .weekly }
            .filter { supplement in
                guard let time = supplement.timeOfDay else { return true }
                switch time {
                case .withMeal:
                    return true
                case .morning:
                    return currentBand == .morning
                case .afternoon:
                    return currentBand == .afternoon
                case .evening, .beforeBed:
                    return currentBand == .evening
                }
            }
            .prefix(3)
            .map { supplement in
                let suffix: String
                if let time = supplement.timeOfDay {
                    suffix = " (\(supplementTimeTitle(time)))"
                } else {
                    suffix = ""
                }
                return LanguageGuard.sanitized("Take \(supplement.name)\(suffix).")
            }
    }

    private func currentTimeBand(date: Date = Date()) -> SupplementTime {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        default:
            return .evening
        }
    }

    private func supplementTimeTitle(_ time: SupplementTime) -> String {
        switch time {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .withMeal: return "With meal"
        case .beforeBed: return "Before bed"
        }
    }

    private func healthContextNote(for conditions: [Condition]) -> String? {
        if conditions.contains(.pcos) {
            return "PCOS in your history — plan focuses on balanced meals, protein, and consistency."
        }
        if conditions.contains(.diabetes) {
            return "Diabetes is in your history, so the plan keeps meal guidance balanced and steady."
        }
        if conditions.contains(.pregnancy) {
            return "Pregnancy is in your history, so the plan keeps the focus on steady meals, hydration, and recovery."
        }
        if conditions.contains(.eatingDisorderHistory) {
            return "Your history calls for a gentler framing — regular meals, protein, and recovery come first."
        }
        if conditions.contains(.anemiaLowIron) || conditions.contains(.highBloodPressure) || conditions.contains(.highCholesterol) || conditions.contains(.thyroidCondition) {
            return "Condition-specific needs should follow your healthcare provider’s advice."
        }
        return nil
    }

    private func safetyNote(for conditions: [Condition]) -> String? {
        if conditions.contains(.diabetes) {
            return "For diabetes-specific nutrition, please follow your clinician's advice."
        }
        if conditions.contains(.pregnancy) {
            return "Pregnancy nutrition needs should be discussed with a qualified healthcare professional."
        }
        if conditions.contains(.eatingDisorderHistory) {
            return "If food tracking feels stressful, consider using BeU without calorie targets."
        }
        if conditions.contains(.pcos) || conditions.contains(.anemiaLowIron) || conditions.contains(.highBloodPressure) || conditions.contains(.highCholesterol) || conditions.contains(.thyroidCondition) {
            return "For condition-specific medical nutrition, please consult your healthcare provider."
        }
        return BeUSafetyCopy.wellnessDisclaimer
    }
}
