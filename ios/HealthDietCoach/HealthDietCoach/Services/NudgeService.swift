import Foundation

struct NudgeService {
    func buildNudges(plan: DailyPlan, intake: DailyIntake) -> [DailyNudge] {
        if plan.adaptivePlan.nudges.isEmpty == false {
            return Array(plan.adaptivePlan.nudges.prefix(3)).enumerated().map { index, nudge in
                DailyNudge(
                    id: "adaptive-\(index)-\(nudge.category)",
                    tone: tone(for: nudge),
                    message: LanguageGuard.sanitized(nudge.message),
                    action: action(for: nudge)
                )
            }
        }

        let proteinShort = plan.proteinTarget - intake.protein
        let kcalOver = intake.kcal - plan.kcalTarget
        let litresShort = plan.waterLitresTarget - intake.waterLitres
        let stepsShort = plan.cardioStepsTarget - intake.steps
        let remainingBurn = plan.energyBalance.remainingBurnTarget
        let workoutBurn = plan.energyBalance.workoutEnergyBurned

        var nudges: [DailyNudge] = []

        if proteinShort <= 0, kcalOver <= 0, remainingBurn <= 0 {
            nudges.append(
                DailyNudge(
                    id: "win",
                    tone: .win,
                    message: LanguageGuard.sanitized("You're on track — nice consistency today."),
                    action: nil
                )
            )
        }

        if plan.strength.kind == .rest, remainingBurn > 0 {
            nudges.append(
                DailyNudge(
                    id: "recovery",
                    tone: .soft,
                    message: LanguageGuard.sanitized("Recovery is low, so don't chase burn aggressively today. Keep movement light."),
                    action: nil
                )
            )
        }

        if proteinShort > 25 {
            nudges.append(
                DailyNudge(
                    id: "protein",
                    tone: .soft,
                    message: LanguageGuard.sanitized("You're \(proteinShort)g short on protein."),
                    action: "Log meal"
                )
            )
        }

        if workoutBurn > 250 {
            nudges.append(
                DailyNudge(
                    id: "workout",
                    tone: .soft,
                    message: LanguageGuard.sanitized("You burned \(workoutBurn) kcal in your workout. Make your next meal protein-led."),
                    action: "Log meal"
                )
            )
        }

        if kcalOver > 150, remainingBurn > 150 {
            nudges.append(
                DailyNudge(
                    id: "kcal",
                    tone: .alert,
                    message: LanguageGuard.sanitized("Calories are above target and activity is behind. Keep dinner lighter and add a short walk."),
                    action: nil
                )
            )
        }

        if litresShort > 0.5 {
            nudges.append(
                DailyNudge(
                    id: "water",
                    tone: .soft,
                    message: LanguageGuard.sanitized("Hydration is behind — drink a glass."),
                    action: "+100 ml"
                )
            )
        }

        if remainingBurn <= 0 {
            nudges.append(
                DailyNudge(
                    id: "burn-met",
                    tone: .win,
                    message: LanguageGuard.sanitized("You've met today's burn target. Extra movement is optional."),
                    action: nil
                )
            )
        } else if remainingBurn > 250, plan.strength.kind != .rest {
            nudges.append(
                DailyNudge(
                    id: "steps",
                    tone: .soft,
                    message: LanguageGuard.sanitized("You're around \(remainingBurn) kcal short of today's burn target. A 25-minute walk can help close the gap."),
                    action: nil
                )
            )
        } else if stepsShort > 2500 {
            nudges.append(
                DailyNudge(
                    id: "steps-gap",
                    tone: .soft,
                    message: LanguageGuard.sanitized("\(stepsShort) steps to your goal — short walk?"),
                    action: nil
                )
            )
        }

        return Array(nudges.prefix(3))
    }

    private func tone(for nudge: AdaptivePlanOutput.AdaptiveNudge) -> NudgeTone {
        switch nudge.urgency {
        case "high":
            return nudge.category == "recovery" ? .soft : .alert
        case "medium":
            return .soft
        default:
            return nudge.category == "activity" ? .win : .soft
        }
    }

    private func action(for nudge: AdaptivePlanOutput.AdaptiveNudge) -> String? {
        switch nudge.category {
        case "nutrition":
            return "Log meal"
        case "hydration":
            return "+100 ml"
        default:
            return nil
        }
    }
}
