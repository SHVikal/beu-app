import Foundation

struct AdaptiveMealGuidanceService {
    func build(input: AdaptivePlanInput, planMode: String, caloriesRemaining: Int, proteinRemaining: Double) -> AdaptivePlanOutput.MealGuidance {
        let baseStrategy = proteinRemaining >= 40
            ? "Choose paneer, tofu, soya, dal, curd, or sprouts."
            : "Keep the next meal balanced and practical."

        let focus: String
        let strategy: String

        switch planMode {
        case "protein_behind":
            focus = "Protein-led meal"
            strategy = "Choose paneer, tofu, soya, dal, curd, or sprouts."
        case "calories_tight":
            focus = "Lean high-protein meal"
            strategy = "Keep calories controlled and prioritize protein."
        case "activity_ahead":
            focus = "Protein + balanced carbs"
            strategy = "You can include a moderate carb portion if it fits your target."
        case "activity_behind":
            focus = "Light protein-led meal"
            strategy = "Avoid heavy calorie-dense meals until activity catches up."
        case "recovery_first":
            focus = "Balanced recovery meal"
            strategy = "Keep meals balanced, hydrating, and easy."
        case "refuel_needed":
            focus = "Protein-led refuel meal"
            strategy = "Keep the next meal protein-led and add a moderate carb portion."
        default:
            focus = "Stay on plan"
            strategy = baseStrategy
        }

        var suggestedMealTypes: [String] = []
        let hour = input.todayContext.currentHour ?? Calendar.current.component(.hour, from: Date())
        if input.todayContext.mealsLoggedToday == 0 && hour < 11 {
            suggestedMealTypes.append("breakfast")
        }
        if hour >= 11 && hour < 17 {
            suggestedMealTypes.append("lunch")
        }
        if hour >= 17 {
            suggestedMealTypes.append("dinner")
        }
        suggestedMealTypes.append("snack")

        var finalStrategy = strategy
        if input.todayContext.healthConditions.contains("PCOS") {
            finalStrategy += " PCOS context: keep meals balanced, protein-led, and fiber-rich."
        }
        if caloriesRemaining <= 300 && proteinRemaining >= 25 {
            finalStrategy = "Keep calories controlled and prioritize protein."
        }

        return .init(dietFocus: focus, nextMealStrategy: finalStrategy, suggestedMealTypes: Array(NSOrderedSet(array: suggestedMealTypes)) as? [String] ?? suggestedMealTypes)
    }
}

struct AdaptiveTrainingGuidanceService {
    func activityAdvice(input: AdaptivePlanInput, planMode: String, stepsRemaining: Int) -> AdaptivePlanOutput.ActivityAdvice {
        let recommendation: String
        let burn: Int?
        let message: String

        switch planMode {
        case "recovery_first":
            recommendation = "Light walk only."
            burn = 60
            message = "Do not chase burn aggressively today."
        case "activity_ahead":
            recommendation = "Extra cardio is optional."
            burn = nil
            message = "You’re already ahead on movement today."
        case "activity_behind", "calories_tight":
            let gap = max(stepsRemaining, 0)
            if gap >= 4500 {
                recommendation = "40 min easy walk"
                burn = 160
            } else if gap >= 2500 {
                recommendation = "30 min easy walk"
                burn = 120
            } else {
                recommendation = "20 min easy walk"
                burn = 80
            }
            message = "A practical walk can help close the gap without overcomplicating the day."
        default:
            recommendation = input.goal.goalType == "muscle_gain" ? "Keep cardio light and focus on strength/protein." : "Stay consistent with normal movement."
            burn = input.goal.goalType == "muscle_gain" ? 50 : nil
            message = input.goal.goalType == "muscle_gain" ? "Keep cardio light and let training lead the day." : "Movement is broadly on track."
        }

        return .init(
            stepTarget: input.baseTargets.stepTarget,
            stepsRemaining: max(stepsRemaining, 0),
            cardioRecommendation: recommendation,
            estimatedCardioBurnKcal: burn,
            message: message
        )
    }

    func strengthAdvice(input: AdaptivePlanInput, planMode: String) -> AdaptivePlanOutput.StrengthAdvice {
        if input.todayContext.workoutToday {
            return .init(
                recommendation: "Strength done today",
                durationMinutes: 0,
                intensity: "complete",
                estimatedBurnKcal: input.progress.workoutEnergyBurnedKcal,
                message: "Focus on recovery and protein now."
            )
        }

        if planMode == "recovery_first" {
            return .init(
                recommendation: "Recovery strength / mobility",
                durationMinutes: 20,
                intensity: "light",
                estimatedBurnKcal: 60,
                message: "Keep the session light and recovery-focused."
            )
        }

        if input.goal.goalType == "muscle_gain" {
            let sessions = input.historicalPerformance.strengthSessionsLast7Days ?? 0
            if sessions < 3 {
                return .init(
                    recommendation: "Strength session",
                    durationMinutes: 40,
                    intensity: "moderate",
                    estimatedBurnKcal: 210,
                    message: "Strength is the main lever for your goal right now."
                )
            }
        }

        if input.goal.goalType == "fat_loss", input.todayContext.workoutYesterday == false {
            return .init(
                recommendation: "Strength session",
                durationMinutes: 35,
                intensity: "moderate",
                estimatedBurnKcal: 180,
                message: "A balanced strength session supports your goal without chasing extra cardio."
            )
        }

        return .init(
            recommendation: "Strength session",
            durationMinutes: 30,
            intensity: "moderate",
            estimatedBurnKcal: 150,
            message: "A short, consistent strength session keeps the week on track."
        )
    }
}

struct AdaptiveNudgeService {
    func buildNudges(input: AdaptivePlanInput, planMode: String, proteinRemaining: Double, caloriesRemaining: Int, stepsRemaining: Int) -> [AdaptivePlanOutput.AdaptiveNudge] {
        var nudges: [AdaptivePlanOutput.AdaptiveNudge] = []

        if planMode == "recovery_first" {
            nudges.append(.init(message: "Recovery is lower today. Keep movement light and prioritize sleep.", reason: "readiness is low", urgency: "high", category: "recovery"))
        }

        if proteinRemaining >= 25 {
            nudges.append(.init(message: "You’re still \(Int(proteinRemaining.rounded()))g short on protein. Make your next meal protein-led.", reason: "protein gap", urgency: proteinRemaining >= 50 ? "high" : "medium", category: "nutrition"))
        }

        if caloriesRemaining <= 250 && proteinRemaining >= 20 {
            nudges.append(.init(message: "Calories are tight, but protein is behind. Choose a lean protein option.", reason: "calories limited", urgency: "high", category: "nutrition"))
        }

        if planMode == "activity_behind" || (planMode == "calories_tight" && stepsRemaining > 1500) {
            nudges.append(.init(message: "You’re behind on movement. A 20–40 minute walk can help close the gap.", reason: "activity gap", urgency: "medium", category: "activity"))
        }

        if input.todayContext.workoutToday && proteinRemaining > 0 {
            nudges.append(.init(message: "You trained today. Prioritize protein in your next meal.", reason: "refuel need", urgency: "medium", category: "nutrition"))
        }

        if let due = input.todayContext.supplementsDue.first(where: { $0.status != "taken" }) {
            nudges.append(.init(message: "\(due.name) is still due today.", reason: "supplement due", urgency: "low", category: "supplement"))
        }

        if planMode == "activity_ahead" {
            nudges.append(.init(message: "You’re ahead on movement today. Extra cardio is optional.", reason: "activity ahead", urgency: "low", category: "activity"))
        }

        return Array(nudges.prefix(3))
    }
}

struct AdaptivePlanService {
    private let mealGuidanceService = AdaptiveMealGuidanceService()
    private let trainingGuidanceService = AdaptiveTrainingGuidanceService()
    private let nudgeService = AdaptiveNudgeService()

    func build(input: AdaptivePlanInput) -> AdaptivePlanOutput {
        let caloriesRemaining = input.baseTargets.calorieTarget - input.progress.caloriesConsumed
        let proteinRemaining = max(Double(input.baseTargets.proteinTargetGrams) - input.progress.proteinConsumedGrams, 0)
        let stepsRemaining = max(input.baseTargets.stepTarget - input.progress.stepsCompleted, 0)
        let expectedProgress = progressExpectation(for: input.todayContext.currentHour)
        let stepProgressRatio = Double(input.progress.stepsCompleted) / Double(max(input.baseTargets.stepTarget, 1))
        let burnProgressRatio: Double = {
            guard let target = input.baseTargets.burnTargetKcal, target > 0,
                  let active = input.progress.activeEnergyBurnedKcal else { return 0 }
            return Double(active) / Double(target)
        }()
        let proteinProgressRatio = input.progress.proteinConsumedGrams / Double(max(input.baseTargets.proteinTargetGrams, 1))
        let calorieProgressRatio = Double(input.progress.caloriesConsumed) / Double(max(input.baseTargets.calorieTarget, 1))

        let planMode: String
        if input.readiness.status == "low" || input.historicalPerformance.readinessTrend == "declining" {
            planMode = "recovery_first"
        } else if caloriesRemaining <= 250 && proteinRemaining >= 20 {
            planMode = "calories_tight"
        } else if proteinRemaining >= 40 || proteinProgressRatio + 0.20 < calorieProgressRatio {
            planMode = "protein_behind"
        } else if isActivityBehind(input: input, expectedProgress: expectedProgress, stepProgressRatio: stepProgressRatio, burnProgressRatio: burnProgressRatio) {
            planMode = "activity_behind"
        } else if isActivityAhead(input: input, stepProgressRatio: stepProgressRatio, burnProgressRatio: burnProgressRatio) {
            planMode = "activity_ahead"
        } else if (input.todayContext.workoutToday || (input.progress.workoutEnergyBurnedKcal ?? 0) >= 250) && proteinRemaining > 0 {
            planMode = "refuel_needed"
        } else {
            planMode = "stay_on_plan"
        }

        let calorieAdvice = buildCalorieAdvice(input: input, planMode: planMode, caloriesRemaining: caloriesRemaining)
        let proteinAdvice = buildProteinAdvice(input: input, proteinRemaining: proteinRemaining, caloriesRemaining: caloriesRemaining)
        let activityAdvice = trainingGuidanceService.activityAdvice(input: input, planMode: planMode, stepsRemaining: stepsRemaining)
        let strengthAdvice = trainingGuidanceService.strengthAdvice(input: input, planMode: planMode)
        let mealGuidance = mealGuidanceService.build(input: input, planMode: planMode, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining)
        let nextBestActions = buildActions(input: input, planMode: planMode, proteinRemaining: proteinRemaining, caloriesRemaining: caloriesRemaining, stepsRemaining: stepsRemaining)
        let nudges = nudgeService.buildNudges(input: input, planMode: planMode, proteinRemaining: proteinRemaining, caloriesRemaining: caloriesRemaining, stepsRemaining: stepsRemaining)
        let explanation = buildExplanation(input: input, planMode: planMode, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining)

        return .init(
            planMode: planMode,
            calorieAdvice: calorieAdvice,
            proteinAdvice: proteinAdvice,
            activityAdvice: activityAdvice,
            strengthAdvice: strengthAdvice,
            mealGuidance: mealGuidance,
            nextBestActions: nextBestActions,
            nudges: nudges,
            explanation: explanation
        )
    }

    private func progressExpectation(for hour: Int?) -> Double? {
        guard let hour else { return nil }
        switch hour {
        case ..<10: return nil
        case 10..<14: return 0.35
        case 14..<18: return 0.65
        default: return 0.80
        }
    }

    private func isActivityBehind(input: AdaptivePlanInput, expectedProgress: Double?, stepProgressRatio: Double, burnProgressRatio: Double) -> Bool {
        guard input.readiness.status != "low", let expectedProgress else { return false }
        let stepBehind = stepProgressRatio + 0.15 < expectedProgress
        let burnBehind: Bool
        if input.baseTargets.burnTargetKcal != nil, input.progress.activeEnergyBurnedKcal != nil {
            burnBehind = burnProgressRatio + 0.18 < expectedProgress
        } else {
            burnBehind = false
        }
        return stepBehind || burnBehind
    }

    private func isActivityAhead(input: AdaptivePlanInput, stepProgressRatio: Double, burnProgressRatio: Double) -> Bool {
        let beforeEvening = (input.todayContext.currentHour ?? 23) < 18
        let stepsAhead = beforeEvening && stepProgressRatio >= 0.85
        let burnAhead = beforeEvening && burnProgressRatio >= 0.95
        return (stepsAhead || burnAhead) && ["high", "good", "moderate"].contains(input.readiness.status)
    }

    private func buildCalorieAdvice(input: AdaptivePlanInput, planMode: String, caloriesRemaining: Int) -> AdaptivePlanOutput.CalorieAdvice {
        let message: String
        let action: String
        switch planMode {
        case "activity_ahead":
            message = "You’re ahead on activity today. Keep your calorie target steady and prioritize protein."
            action = "Keep calories steady"
        case "activity_behind" where input.progress.caloriesConsumed >= Int(Double(input.baseTargets.calorieTarget) * 0.8):
            message = "Activity is behind and calories are close to target. Keep the next meal lighter and protein-led."
            action = "Keep the next meal lighter"
        case "calories_tight":
            message = "Calories are tight, but protein is still behind. Choose lean protein for your next meal."
            action = "Choose lean protein"
        case "recovery_first":
            message = "Recovery is lower today. Avoid chasing a large deficit and keep meals balanced."
            action = "Keep meals balanced"
        case "refuel_needed":
            message = "You trained today. Keep the target steady and make your next meal protein-led."
            action = "Refuel with protein"
        default:
            message = caloriesRemaining < 0 ? "Calories are already over target, so keep the rest of the day light and balanced." : "Your calorie target stays steady. Use the rest of the day to land close to target."
            action = "Stay on target"
        }
        return .init(baseTarget: input.baseTargets.calorieTarget, recommendedAction: action, message: message)
    }

    private func buildProteinAdvice(input: AdaptivePlanInput, proteinRemaining: Double, caloriesRemaining: Int) -> AdaptivePlanOutput.ProteinAdvice {
        let urgency: String
        if proteinRemaining >= 50 {
            urgency = "high"
        } else if proteinRemaining >= 25 {
            urgency = "medium"
        } else {
            urgency = "low"
        }

        let message: String
        if caloriesRemaining <= 300 && proteinRemaining >= 25 {
            message = "Protein is still behind while calories are limited. Choose lean protein."
        } else if input.todayContext.workoutToday {
            message = "You trained today, so protein should be a priority in your next meal."
        } else {
            message = proteinRemaining > 0 ? "Keep protein moving steadily so the day does not get compressed late." : "Protein is on track for today."
        }

        return .init(targetGrams: input.baseTargets.proteinTargetGrams, remainingGrams: proteinRemaining, urgency: urgency, message: message)
    }

    private func buildActions(input: AdaptivePlanInput, planMode: String, proteinRemaining: Double, caloriesRemaining: Int, stepsRemaining: Int) -> [AdaptivePlanOutput.NextBestAction] {
        var actions: [AdaptivePlanOutput.NextBestAction] = []

        switch planMode {
        case "recovery_first":
            actions.append(.init(title: "Keep movement light", description: "Use a short walk or mobility instead of chasing burn.", category: "recovery", priority: "high"))
        case "calories_tight":
            actions.append(.init(title: "Make the next meal lean and protein-led", description: "Use protein first and keep calories controlled.", category: "nutrition", priority: "high"))
        case "protein_behind":
            actions.append(.init(title: "Close the protein gap", description: "Aim for a protein-led meal next.", category: "nutrition", priority: "high"))
        case "activity_behind":
            actions.append(.init(title: "Add a practical walk", description: "A short easy walk can close the gap without overdoing it.", category: "activity", priority: "high"))
        case "activity_ahead":
            actions.append(.init(title: "Keep calories steady", description: "You do not need to eat back movement aggressively.", category: "nutrition", priority: "medium"))
        case "refuel_needed":
            actions.append(.init(title: "Refuel with protein", description: "Make your next meal protein-led and steady.", category: "nutrition", priority: "high"))
        default:
            actions.append(.init(title: "Stay on plan", description: "Keep meals, fluids, and movement consistent.", category: "nutrition", priority: "medium"))
        }

        if stepsRemaining > 0 && planMode != "recovery_first" && planMode != "activity_ahead" {
            actions.append(.init(title: "Keep moving", description: "\(stepsRemaining.formatted()) steps remain against today’s target.", category: "activity", priority: "medium"))
        }
        if proteinRemaining > 0 {
            actions.append(.init(title: "Prioritize protein", description: "You still have \(Int(proteinRemaining.rounded()))g remaining.", category: "nutrition", priority: proteinRemaining >= 40 ? "high" : "medium"))
        }
        if caloriesRemaining <= 250 {
            actions.append(.init(title: "Land the day carefully", description: "Keep the next choice light, balanced, and precise.", category: "nutrition", priority: "medium"))
        }

        return Array(actions.prefix(3))
    }

    private func buildExplanation(input: AdaptivePlanInput, planMode: String, caloriesRemaining: Int, proteinRemaining: Double) -> [String] {
        var lines: [String] = []
        lines.append("Base calorie, protein, step, and water targets stay stable while BeU adapts the recommendation layer.")
        lines.append("The current recommendation uses today’s intake, movement, readiness, and time of day.")
        if input.todayContext.healthConditions.contains("PCOS") {
            lines.append("PCOS context keeps meal advice balanced, protein-led, and fiber-aware.")
        }
        if planMode == "activity_ahead" {
            lines.append("Activity is ahead today, so BeU keeps calories steady instead of raising the target.")
        }
        if planMode == "calories_tight" || (caloriesRemaining <= 250 && proteinRemaining >= 20) {
            lines.append("Calories are tight and protein is still behind, so the next meal should solve protein efficiently.")
        }
        return lines
    }
}

