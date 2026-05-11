import Foundation

struct BaseTargets: Codable, Equatable {
    let calories: Int
    let proteinGrams: Double
    let steps: Int
    let waterLiters: Double
    let burnTargetKcal: Int?
}

struct TodayProgress: Codable, Equatable {
    let caloriesConsumed: Int
    let proteinConsumedGrams: Double
    let carbsConsumedGrams: Double
    let fatConsumedGrams: Double
    let mealsLogged: Int
    let waterConsumedLiters: Double?
}

struct DailyPerformanceSummary: Codable, Equatable {
    let date: Date
    let caloriesConsumed: Int
    let proteinConsumedGrams: Double
    let steps: Int
    let activeEnergyBurnedKcal: Int?
    let readinessScore: Int?
    let workoutCompleted: Bool
}

struct DynamicTargetContext {
    let date: Date
    let profile: Baseline?
    let goal: GoalConfig?
    let baseTargets: BaseTargets
    let todayProgress: TodayProgress
    let healthToday: HealthSummary?
    let readiness: Readiness?
    let last7Days: [DailyPerformanceSummary]
    let currentHour: Int
}

enum DynamicTargetMode: String, Codable, Equatable {
    case onTrack = "on_track"
    case activityAhead = "activity_ahead"
    case activityBehind = "activity_behind"
    case nutritionBehind = "nutrition_behind"
    case caloriesOver = "calories_over"
    case recoveryFirst = "recovery_first"
    case aggressiveGoalCorrection = "aggressive_goal_correction"
    case weeklyUnderperforming = "weekly_underperforming"
    case weeklyOverperforming = "weekly_overperforming"
}

struct AdaptiveTargets: Codable, Equatable {
    let calories: Int
    let proteinGrams: Double
    let steps: Int
    let waterLiters: Double
    let cardioMinutes: Int
    let cardioEstimatedBurnKcal: Int
    let strengthMinutes: Int
    let strengthEstimatedBurnKcal: Int
    let strengthIntensity: String
}

struct TargetChange: Codable, Equatable, Identifiable {
    var id: String { targetName }

    let targetName: String
    let oldValue: String
    let newValue: String
    let reason: String
}

struct DynamicTargetResult: Codable, Equatable {
    let baseTargets: BaseTargets
    let adaptiveTargets: AdaptiveTargets
    let targetChanges: [TargetChange]
    let planMode: DynamicTargetMode
    let explanation: [String]
}

struct DynamicTargetService {
    func generateDynamicTargets(context: DynamicTargetContext) -> DynamicTargetResult {
        let goal = context.goal?.goal ?? .wellness
        let profile = context.profile
        let healthToday = context.healthToday
        let readiness = context.readiness
        let conditions = Set((profile?.medical ?? []).filter { $0 != .none && $0 != .preferNotToSay })
        let readinessLow = readiness?.status == .low
        let currentHour = context.currentHour

        let todaySteps = healthToday?.steps ?? 0
        let activeEnergyToday = Int((healthToday?.activeEnergyKcal ?? 0).rounded())
        let workoutBurnToday = Int((healthToday?.workoutEnergyKcal ?? 0).rounded())
        let workoutToday = (healthToday?.workoutCount ?? 0) > 0 || workoutBurnToday >= 100

        let sevenDayAverageSteps = average(context.last7Days.compactMap { $0.steps > 0 ? $0.steps : nil })
        let sevenDayAverageActiveEnergy = average(context.last7Days.compactMap(\.activeEnergyBurnedKcal))
        let stepHitDays = context.last7Days.filter { $0.steps >= context.baseTargets.steps }.count
        let proteinHitDays = context.last7Days.filter { $0.proteinConsumedGrams >= context.baseTargets.proteinGrams }.count
        let calorieHitDays = context.last7Days.filter { caloriesHit(for: goal, consumed: $0.caloriesConsumed, target: context.baseTargets.calories) }.count
        let caloriesRemainingFromBase = context.baseTargets.calories - context.todayProgress.caloriesConsumed
        let proteinRemainingFromBase = context.baseTargets.proteinGrams - context.todayProgress.proteinConsumedGrams
        let hasSafetyBlock = conditions.contains(.pregnancy) || conditions.contains(.eatingDisorderHistory)

        let weeklyStepRaised = stepHitDays >= 6 && sevenDayAverageSteps >= context.baseTargets.steps + 1_500
        let weeklyStepLowered = stepHitDays <= 2 && sevenDayAverageSteps > 0

        var adaptiveSteps = context.baseTargets.steps
        var adaptiveStepReason: String?
        if weeklyStepRaised {
            let increase = sevenDayAverageSteps >= context.baseTargets.steps + 2_500 ? 1_000 : 500
            adaptiveSteps = min(12_000, context.baseTargets.steps + increase)
            adaptiveStepReason = "You have consistently exceeded your step target."
        } else if weeklyStepLowered {
            adaptiveSteps = max(4_000, sevenDayAverageSteps + 1_000)
            adaptiveStepReason = "Recent step performance is lower, so the target is more achievable today."
        }
        if readinessLow {
            let lowered = max(4_000, Int((Double(adaptiveSteps) * 0.88).rounded()))
            if lowered != adaptiveSteps {
                adaptiveSteps = lowered
                adaptiveStepReason = "Recovery is low, so today’s step target is lighter."
            }
        }

        let expectedProgress = expectedProgressRatio(for: currentHour)
        let stepProgressRatio = Double(todaySteps) / Double(max(adaptiveSteps, 1))
        let burnProgressRatio: Double = {
            guard let burnTarget = context.baseTargets.burnTargetKcal, burnTarget > 0 else { return 0 }
            return Double(activeEnergyToday) / Double(burnTarget)
        }()

        let stepAheadToday = currentHour < 18 && stepProgressRatio >= 0.85
        let burnAheadToday: Bool = {
            guard let expectedProgress, let burnTarget = context.baseTargets.burnTargetKcal, burnTarget > 0 else { return false }
            let requiredRatio = min(expectedProgress + 0.20, 1.35)
            return Double(activeEnergyToday) >= Double(burnTarget) * requiredRatio
        }()
        let activityAheadToday = stepAheadToday || burnAheadToday

        let stepBehindToday: Bool = {
            guard let expectedProgress, currentHour >= 10 else { return false }
            return stepProgressRatio + 0.15 < expectedProgress
        }()
        let burnBehindToday: Bool = {
            guard let expectedProgress, let burnTarget = context.baseTargets.burnTargetKcal, burnTarget > 0, currentHour >= 10 else { return false }
            let threshold = max(expectedProgress - 0.15, 0.15)
            return Double(activeEnergyToday) < Double(burnTarget) * threshold
        }()
        let activityBehindToday = (stepBehindToday || burnBehindToday) && !readinessLow
        let veryHighBurnDay = sevenDayAverageActiveEnergy > 0 && Double(activeEnergyToday) >= Double(sevenDayAverageActiveEnergy) * 1.35 && !readinessLow

        var adaptiveCalories = context.baseTargets.calories
        var adaptiveCalorieReason: String?
        let calorieBounds = calorieBounds(for: goal)
        let calorieFloor = calorieFloor(for: profile?.gender)
        let lowerCalorieBound = max(calorieFloor, context.baseTargets.calories + calorieBounds.minDelta)
        let upperCalorieBound = context.baseTargets.calories + calorieBounds.maxDelta

        if !readinessLow {
            if veryHighBurnDay {
                adaptiveCalories += calorieIncreaseForVeryHighBurn(goal: goal)
                adaptiveCalorieReason = "You burned more than usual today."
            } else if activityAheadToday {
                adaptiveCalories += calorieIncreaseForActivityAhead(goal: goal)
                adaptiveCalorieReason = "Activity is ahead today."
            } else if currentHour >= 18,
                      todaySteps < Int(Double(adaptiveSteps) * 0.5),
                      burnBehindToday,
                      goal == .fatLoss,
                      hasSafetyBlock == false {
                adaptiveCalories -= 100
                adaptiveCalorieReason = "Activity is behind today, so BeU is keeping the target tighter."
            }
        }

        if context.todayProgress.caloriesConsumed > context.baseTargets.calories, !activityAheadToday, !veryHighBurnDay {
            adaptiveCalories = min(adaptiveCalories, context.baseTargets.calories)
            if goal == .fatLoss,
               currentHour >= 18,
               burnBehindToday,
               !readinessLow,
               hasSafetyBlock == false {
                adaptiveCalories = max(lowerCalorieBound, context.baseTargets.calories - 100)
            }
            adaptiveCalorieReason = "Calories are above target, so BeU is not increasing the target unless activity supports it."
        }

        if readinessLow {
            adaptiveCalories = context.baseTargets.calories
            adaptiveCalorieReason = nil
        }

        adaptiveCalories = min(max(adaptiveCalories, lowerCalorieBound), upperCalorieBound)
        adaptiveCalories = max(adaptiveCalories, calorieFloor)

        var adaptiveProtein = context.baseTargets.proteinGrams
        var adaptiveProteinReason: String?
        let proteinMissedOften = proteinHitDays <= 3
        let caloriesTight = caloriesRemainingFromBase <= 300 && proteinRemainingFromBase >= 25

        if proteinMissedOften {
            adaptiveProtein = context.baseTargets.proteinGrams
            adaptiveProteinReason = nil
        } else if !caloriesTight {
            if workoutToday {
                adaptiveProtein = context.baseTargets.proteinGrams + 10
                adaptiveProteinReason = "Workout completed today."
            } else if sevenDayAverageActiveEnergy > 0 && Double(activeEnergyToday) >= Double(sevenDayAverageActiveEnergy) * 1.25 {
                adaptiveProtein = max(adaptiveProtein, context.baseTargets.proteinGrams + 10)
                adaptiveProteinReason = "You burned more than usual today."
            }

            if goal == .muscle && proteinHitDays >= 5 {
                let raised = max(adaptiveProtein, context.baseTargets.proteinGrams + 5)
                if raised != adaptiveProtein || adaptiveProteinReason == nil {
                    adaptiveProtein = raised
                    adaptiveProteinReason = adaptiveProteinReason ?? "Protein has been consistent, so today’s target is slightly higher."
                }
            }
        }
        adaptiveProtein = min(adaptiveProtein, context.baseTargets.proteinGrams + 20)

        let workoutCompletedRecently = workedOutInLast(days: 2, summaries: context.last7Days, referenceDate: context.date)
        let baseCardio = baseCardioMinutes(for: goal)
        let baseStrength = baseStrengthRecommendation(for: goal)

        var cardioMinutes = baseCardio
        var cardioBurn = estimatedCardioBurn(for: baseCardio)
        var cardioReason: String?
        if readinessLow {
            cardioMinutes = 12
            cardioBurn = 50
            cardioReason = "Recovery is low, so BeU is keeping movement lighter."
        } else if activityAheadToday {
            cardioMinutes = goal == .muscle ? 10 : 0
            cardioBurn = goal == .muscle ? 40 : 0
            cardioReason = "Burn target is already on track."
        } else if activityBehindToday {
            let stepsGap = max(adaptiveSteps - todaySteps, 0)
            let recommended = stepsGap >= 4_500 ? 40 : (stepsGap >= 2_500 ? 30 : 20)
            if goal == .muscle {
                cardioMinutes = min(recommended, 20)
            } else {
                cardioMinutes = recommended
            }
            cardioBurn = estimatedCardioBurn(for: cardioMinutes)
            cardioReason = "Activity is behind today."
        }

        var strengthMinutes = baseStrength.minutes
        var strengthBurn = baseStrength.burn
        var strengthIntensity = baseStrength.intensity
        var strengthReason: String?
        if workoutToday {
            strengthMinutes = 0
            strengthBurn = max(workoutBurnToday, baseStrength.burn)
            strengthIntensity = "done"
            strengthReason = "Workout completed today."
        } else if readinessLow {
            strengthMinutes = 20
            strengthBurn = 60
            strengthIntensity = "light"
            strengthReason = "Recovery is low, so strength stays lighter."
        } else if goal == .muscle {
            if workoutCompletedRecently {
                strengthMinutes = 30
                strengthBurn = 150
                strengthIntensity = "moderate"
            } else {
                strengthMinutes = 40
                strengthBurn = 210
                strengthIntensity = "moderate"
                strengthReason = "Strength has more room this week."
            }
        } else if goal == .fatLoss {
            if workoutCompletedRecently {
                strengthMinutes = 25
                strengthBurn = 120
                strengthIntensity = "light"
            } else {
                strengthMinutes = 35
                strengthBurn = 180
                strengthIntensity = "moderate"
                strengthReason = "Strength supports your goal best when it stays consistent."
            }
        }

        let planMode: DynamicTargetMode
        if readinessLow {
            planMode = .recoveryFirst
        } else if context.todayProgress.caloriesConsumed > context.baseTargets.calories && !activityAheadToday && !veryHighBurnDay {
            planMode = .caloriesOver
        } else if proteinRemainingFromBase >= 30 {
            planMode = .nutritionBehind
        } else if activityBehindToday {
            planMode = .activityBehind
        } else if activityAheadToday {
            planMode = .activityAhead
        } else if weeklyStepRaised {
            planMode = .weeklyOverperforming
        } else if weeklyStepLowered {
            planMode = .weeklyUnderperforming
        } else {
            planMode = .onTrack
        }

        let adaptiveTargets = AdaptiveTargets(
            calories: adaptiveCalories,
            proteinGrams: adaptiveProtein,
            steps: adaptiveSteps,
            waterLiters: context.baseTargets.waterLiters,
            cardioMinutes: cardioMinutes,
            cardioEstimatedBurnKcal: cardioBurn,
            strengthMinutes: strengthMinutes,
            strengthEstimatedBurnKcal: strengthBurn,
            strengthIntensity: strengthIntensity
        )

        var targetChanges: [TargetChange] = []
        if adaptiveCalories != context.baseTargets.calories, let adaptiveCalorieReason {
            targetChanges.append(
                TargetChange(
                    targetName: "calories",
                    oldValue: "\(context.baseTargets.calories) kcal",
                    newValue: "\(adaptiveCalories) kcal",
                    reason: adaptiveCalorieReason
                )
            )
        }
        if adaptiveProtein != context.baseTargets.proteinGrams, let adaptiveProteinReason {
            targetChanges.append(
                TargetChange(
                    targetName: "protein",
                    oldValue: "\(Int(context.baseTargets.proteinGrams.rounded()))g",
                    newValue: "\(Int(adaptiveProtein.rounded()))g",
                    reason: adaptiveProteinReason
                )
            )
        }
        if adaptiveSteps != context.baseTargets.steps, let adaptiveStepReason {
            targetChanges.append(
                TargetChange(
                    targetName: "steps",
                    oldValue: "\(context.baseTargets.steps)",
                    newValue: "\(adaptiveSteps)",
                    reason: adaptiveStepReason
                )
            )
        }
        if cardioMinutes != baseCardio, let cardioReason {
            targetChanges.append(
                TargetChange(
                    targetName: "cardio",
                    oldValue: "\(baseCardio) min",
                    newValue: "\(cardioMinutes) min",
                    reason: cardioReason
                )
            )
        }
        if strengthMinutes != baseStrength.minutes || strengthIntensity != baseStrength.intensity {
            targetChanges.append(
                TargetChange(
                    targetName: "strength",
                    oldValue: "\(baseStrength.minutes) min \(baseStrength.intensity)",
                    newValue: strengthMinutes <= 0 ? "Done today" : "\(strengthMinutes) min \(strengthIntensity)",
                    reason: strengthReason ?? "Today’s strength target reflects your goal and recent training."
                )
            )
        }

        var explanation: [String] = targetChanges.map { "\($0.targetName.capitalized): \($0.reason)" }
        if proteinMissedOften {
            explanation.append("Protein has been missed often, so BeU keeps the target realistic and focuses on earlier protein.")
        }
        if caloriesTight && proteinRemainingFromBase >= 25 {
            explanation.append("Calories are tight today, so BeU is keeping protein guidance practical rather than raising the target.")
        }
        if context.todayProgress.caloriesConsumed > context.baseTargets.calories && !activityAheadToday && !veryHighBurnDay {
            explanation.append("Calories are above target, so BeU is not increasing the target unless activity supports it.")
        }
        if targetChanges.isEmpty {
            explanation.append("Targets are stable today because your progress is broadly in line with your base plan.")
        }

        return DynamicTargetResult(
            baseTargets: context.baseTargets,
            adaptiveTargets: adaptiveTargets,
            targetChanges: targetChanges,
            planMode: planMode,
            explanation: explanation
        )
    }

    private func caloriesHit(for goal: Goal, consumed: Int, target: Int) -> Bool {
        switch goal {
        case .fatLoss:
            return consumed <= target + 100 && consumed >= target - 300
        case .muscle:
            return consumed >= target - 100
        case .maintain, .wellness:
            return abs(consumed - target) <= 200
        }
    }

    private func average(_ values: [Int]) -> Int {
        guard values.isEmpty == false else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private func expectedProgressRatio(for hour: Int) -> Double? {
        switch hour {
        case ..<10:
            return nil
        case 10..<14:
            return 0.35
        case 14..<18:
            return 0.65
        default:
            return 0.80
        }
    }

    private func calorieBounds(for goal: Goal) -> (minDelta: Int, maxDelta: Int) {
        switch goal {
        case .fatLoss:
            return (-100, 200)
        case .muscle:
            return (-100, 300)
        case .maintain:
            return (-200, 200)
        case .wellness:
            return (-150, 150)
        }
    }

    private func calorieFloor(for gender: Gender?) -> Int {
        switch gender {
        case .male:
            return 1_500
        case .female:
            return 1_200
        default:
            return 1_300
        }
    }

    private func calorieIncreaseForActivityAhead(goal: Goal) -> Int {
        switch goal {
        case .fatLoss:
            return 100
        case .maintain:
            return 150
        case .muscle:
            return 200
        case .wellness:
            return 100
        }
    }

    private func calorieIncreaseForVeryHighBurn(goal: Goal) -> Int {
        switch goal {
        case .fatLoss:
            return 150
        case .maintain:
            return 200
        case .muscle:
            return 250
        case .wellness:
            return 150
        }
    }

    private func baseCardioMinutes(for goal: Goal) -> Int {
        switch goal {
        case .muscle:
            return 15
        case .fatLoss:
            return 25
        case .maintain:
            return 20
        case .wellness:
            return 20
        }
    }

    private func estimatedCardioBurn(for minutes: Int) -> Int {
        switch minutes {
        case ..<10:
            return 0
        case ..<20:
            return 50
        case ..<30:
            return 80
        case ..<40:
            return 120
        default:
            return 160
        }
    }

    private func baseStrengthRecommendation(for goal: Goal) -> (minutes: Int, burn: Int, intensity: String) {
        switch goal {
        case .muscle:
            return (40, 210, "moderate")
        case .fatLoss:
            return (35, 180, "moderate")
        case .maintain:
            return (30, 150, "moderate")
        case .wellness:
            return (25, 120, "light")
        }
    }

    private func workedOutInLast(days: Int, summaries: [DailyPerformanceSummary], referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        return summaries.contains { summary in
            guard summary.workoutCompleted else { return false }
            let delta = calendar.dateComponents([.day], from: summary.date, to: referenceDate).day ?? 99
            return delta >= 1 && delta <= days
        }
    }
}
