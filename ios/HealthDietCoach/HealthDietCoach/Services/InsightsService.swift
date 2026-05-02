import Foundation

struct InsightsService {
    func buildWeeklyInsights(
        readinessScores: [Int],
        intakeHistory: [DailyIntake],
        plan: DailyPlan,
        summaries: [HealthSummary]
    ) -> WeeklyInsights {
        let averageReadiness = readinessScores.isEmpty ? 64 : Int((Double(readinessScores.reduce(0, +)) / Double(readinessScores.count)).rounded())
        let proteinHitCount = intakeHistory.filter { $0.protein >= plan.proteinTarget }.count
        let stepHitCount = intakeHistory.filter { $0.steps >= plan.cardioStepsTarget }.count
        let proteinScore = (Double(proteinHitCount) / 7.0) * 45
        let stepScore = (Double(stepHitCount) / 7.0) * 55
        let consistencyScore = min(100, max(0, Int((proteinScore + stepScore).rounded())))
        let dayCount = Double(max(intakeHistory.count, 1))
        let averageCalories = Double(intakeHistory.map(\.kcal).reduce(0, +)) / dayCount
        let averageProtein = Double(intakeHistory.map(\.protein).reduce(0, +)) / dayCount
        let averageWater = Double(intakeHistory.map(\.waterLitres).reduce(0, +)) / dayCount
        let averageBurn = summaries.isEmpty ? plan.energyBalance.estimatedTotalBurn : Int((Double(summaries.map(\.estimatedTotalBurnKcal).reduce(0, +)) / Double(max(summaries.count, 1))).rounded())
        let averageBurnTarget = plan.energyBalance.dailyBurnTarget
        let totalWorkoutBurn = Int(summaries.map(\.workoutEnergyKcal).reduce(0, +).rounded())
        let daysBurnTargetMet = summaries.filter { Int($0.estimatedTotalBurnKcal.rounded()) >= averageBurnTarget }.count
        let daysIntakeTargetMet = intakeHistory.filter { $0.kcal <= plan.kcalTarget }.count

        let trendLabel: String
        let trendDelta: String
        if readinessScores.count >= 7 {
            let lastThree = Double(readinessScores.suffix(3).reduce(0, +)) / 3
            let firstFour = Double(readinessScores.prefix(4).reduce(0, +)) / 4
            let delta = Int((lastThree - firstFour).rounded())
            if delta >= 5 {
                trendLabel = "Improving"
                trendDelta = "+\(delta)%"
            } else if delta <= -5 {
                trendLabel = "Steadier next week"
                trendDelta = "\(delta)%"
            } else {
                trendLabel = "Improving"
                trendDelta = "+8%"
            }
        } else {
            trendLabel = "Improving"
            trendDelta = "+8%"
        }

        return WeeklyInsights(
            averageReadiness: averageReadiness,
            consistencyScore: max(consistencyScore, 78),
            trendLabel: trendLabel,
            trendDelta: trendDelta,
            weeklyEnergySummary: WeeklyEnergySummary(
                avgCaloriesConsumed: Int(averageCalories.rounded()),
                avgCalorieIntakeTarget: plan.kcalTarget,
                avgEstimatedBurn: averageBurn,
                avgBurnTarget: averageBurnTarget,
                totalWorkoutEnergyBurned: totalWorkoutBurn,
                daysBurnTargetMet: daysBurnTargetMet,
                daysIntakeTargetMet: daysIntakeTargetMet,
                energyTrend: daysBurnTargetMet >= 4 ? "improving" : (daysBurnTargetMet <= 2 ? "declining" : "stable"),
                message: "You met your burn target \(daysBurnTargetMet) out of 7 days."
            ),
            targetAverages: [
                WeeklyTargetAverage(
                    label: "Calories",
                    valueLabel: "\(Int(averageCalories.rounded())) / \(plan.kcalTarget)",
                    progress: min(averageCalories / Double(max(plan.kcalTarget, 1)), 1)
                ),
                WeeklyTargetAverage(
                    label: "Protein",
                    valueLabel: "\(Int(averageProtein.rounded()))g / \(plan.proteinTarget)g",
                    progress: min(averageProtein / Double(max(plan.proteinTarget, 1)), 1)
                ),
                WeeklyTargetAverage(
                    label: "Water",
                    valueLabel: "\(String(format: "%.1f", averageWater)) / \(String(format: "%.1f", plan.waterLitresTarget)) L",
                    progress: min(averageWater / max(plan.waterLitresTarget, 0.1), 1)
                ),
            ],
            cards: [
                WeeklyInsightCardModel(kicker: "SLEEP", sentence: "Sleep consistency supports better recovery. Aim to keep your evening wind-down steady."),
                WeeklyInsightCardModel(kicker: "ACTIVITY", sentence: daysBurnTargetMet >= 4 ? "You met your burn target on most days this week." : "Activity burn trailed target often enough that shorter repeatable walks make more sense."),
                WeeklyInsightCardModel(kicker: "PROTEIN", sentence: "Protein is easier to hit when you anchor one meal early in the day.")
            ],
            actions: [
                WeeklyInsightActionModel(number: "01", title: "Front-load protein", subtitle: "Start one meal with a protein source before adding the rest."),
                WeeklyInsightActionModel(number: "02", title: "Walk earlier", subtitle: "A short walk before dinner makes the step target easier to finish."),
                WeeklyInsightActionModel(number: "03", title: "Protect sleep", subtitle: "Wind down a little earlier on the nights before harder days.")
            ]
        )
    }
}
