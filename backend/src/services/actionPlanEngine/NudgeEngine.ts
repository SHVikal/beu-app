import type {
  DailyIntake,
  DailyPersonalizedActionPlan,
  DailyPlanNudge
} from "./actionPlanTypes.js";

export class NudgeEngine {
  buildNudges(plan: DailyPersonalizedActionPlan, intake: DailyIntake): DailyPlanNudge[] {
    const proteinShort = plan.targets.proteinGrams - intake.protein;
    const kcalOver = intake.kcal - plan.targets.calories;
    const stepsShort = plan.targets.steps - intake.steps;
    const litresShort = plan.targets.waterLiters - intake.waterLitres;
    const remainingBurnTarget = plan.energyBalance.remainingBurnTarget;
    const workoutBurn = plan.energyBalance.workoutEnergyBurned;
    const nudges: DailyPlanNudge[] = [];

    if (proteinShort <= 0 && kcalOver <= 0 && remainingBurnTarget <= 0) {
      nudges.push({
        id: "on-track",
        message: "You're on track — nice consistency today.",
        reason: "Protein and calorie intake are both inside today's plan.",
        category: "nutrition",
        urgency: "low",
        tone: "win"
      });
    }

    if (plan.targets.strengthTraining.recommendation === "rest") {
      nudges.push({
        id: "recovery-first",
        message: "Recovery is low, so don't chase burn aggressively today. Keep movement light.",
        reason: "Today's readiness is low, so the plan shifts toward recovery.",
        category: "recovery",
        urgency: "high",
        tone: "soft"
      });
    }

    if (workoutBurn > 250) {
      nudges.push({
        id: "workout-burn",
        message: `You burned ${Math.round(workoutBurn)} kcal in your workout. Make your next meal protein-led.`,
        reason: "Workout energy burn was high enough that recovery nutrition matters more.",
        category: "nutrition",
        urgency: "medium",
        tone: "soft",
        action: "Log meal"
      });
    }

    if (proteinShort > 25) {
      nudges.push({
        id: "protein-short",
        message: `You're ${Math.round(proteinShort)}g short on protein.`,
        reason: "Protein is still trailing your target.",
        category: "nutrition",
        urgency: "medium",
        tone: "soft",
        action: "Log meal"
      });
    }

    if (kcalOver > 150 && remainingBurnTarget > 150) {
      nudges.push({
        id: "kcal-over",
        message: "Calories are above target and activity is behind. Keep dinner lighter and add a short walk.",
        reason: "Today's calories are ahead of plan while burn is still behind target.",
        category: "nutrition",
        urgency: "medium",
        tone: "alert"
      });
    }

    if (litresShort > 0.5) {
      nudges.push({
        id: "water-short",
        message: "Hydration is behind — drink a glass.",
        reason: "Water intake is still behind today's target.",
        category: "hydration",
        urgency: "medium",
        tone: "soft",
        action: "+100 ml"
      });
    }

    if (remainingBurnTarget <= 0) {
      nudges.push({
        id: "burn-target-met",
        message: "You've met today's burn target. Extra movement is optional.",
        reason: "Today's estimated burn already reached target.",
        category: "activity",
        urgency: "low",
        tone: "win"
      });
    } else if (remainingBurnTarget > 250 && plan.targets.strengthTraining.recommendation !== "rest") {
      nudges.push({
        id: "burn-short",
        message: `You're around ${Math.round(remainingBurnTarget)} kcal short of today's burn target. A 25-minute walk can help close the gap.`,
        reason: "Today's burn target is still meaningfully behind target.",
        category: "activity",
        urgency: "medium",
        tone: "soft"
      });
    } else if (stepsShort > 2500) {
      nudges.push({
        id: "steps-short",
        message: `${Math.round(stepsShort)} steps to your goal — short walk?`,
        reason: "A short walk would close most of the remaining gap.",
        category: "activity",
        urgency: "low",
        tone: "soft"
      });
    }

    for (const reminder of plan.supplementReminders) {
      nudges.push({
        id: `supplement-${reminder}`,
        message: reminder,
        reason: "This reminder follows the schedule you saved.",
        category: "supplement",
        urgency: "low",
        tone: "soft"
      });
    }

    const deduped: DailyPlanNudge[] = [];
    for (const nudge of nudges) {
      if (!deduped.some((item) => item.message == nudge.message)) {
        deduped.push(nudge);
      }
      if (deduped.length >= 3) {
        break;
      }
    }
    return deduped;
  }
}
