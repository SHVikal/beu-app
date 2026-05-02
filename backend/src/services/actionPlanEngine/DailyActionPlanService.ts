import { currentIsoDay } from "../../utils/date.js";
import type {
  DailyIntake,
  DailyEnergyBalance,
  DailyPersonalizedActionPlan,
  DailyPlanPriorityAction,
  PersonalizationContext
} from "./actionPlanTypes.js";
import { NudgeEngine } from "./NudgeEngine.js";
import { NutritionTargetService } from "./NutritionTargetService.js";
import { ActivityTargetService } from "./ActivityTargetService.js";
import { WELLNESS_DISCLAIMER, TIME_BAND_TITLES } from "./actionPlanTypes.js";
import { EnergyBalanceService } from "./EnergyBalanceService.js";

function roundToOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

function currentTimeBand(now: Date): "morning" | "afternoon" | "evening" | "before_bed" {
  const hour = now.getHours();
  if (hour < 12) {
    return "morning";
  }
  if (hour < 17) {
    return "afternoon";
  }
  if (hour < 22) {
    return "evening";
  }
  return "before_bed";
}

export class DailyActionPlanService {
  constructor(
    private readonly nutritionTargetService = new NutritionTargetService(),
    private readonly activityTargetService = new ActivityTargetService(),
    private readonly energyBalanceService = new EnergyBalanceService(),
    private readonly nudgeEngine = new NudgeEngine()
  ) {}

  buildPlan(context: PersonalizationContext, date: string = currentIsoDay()): DailyPersonalizedActionPlan {
    if (context.onboardingRequired || context.profile === null || context.profileRecord === null) {
      return {
        userId: context.userId,
        date,
        onboardingRequired: true,
        targets: {
          calories: 0,
          proteinGrams: 0,
          waterLiters: 0,
          steps: 0,
          cardioMinutes: 0,
          strengthTraining: {
            recommendation: "optional",
            durationMinutes: 0,
            intensity: "light",
            focus: "recovery"
          }
        },
        progress: {
          caloriesConsumed: 0,
          caloriesRemaining: 0,
          proteinConsumedGrams: 0,
          proteinRemainingGrams: 0,
          stepsCompleted: 0,
          stepsRemaining: 0,
          waterConsumedLiters: 0,
          waterRemainingLiters: 0
        },
        energyBalance: {
          date,
          calorieIntakeTarget: 0,
          caloriesConsumed: 0,
          activeEnergyBurned: 0,
          basalEnergyBurned: null,
          workoutEnergyBurned: 0,
          estimatedTotalBurn: 0,
          dailyBurnTarget: 0,
          remainingBurnTarget: 0,
          netCalories: 0,
          targetNetCalories: null,
          energyBalanceStatus: "under_target",
          message: "Sync Apple Health and your profile to unlock energy balance."
        },
        planSummary: "Finish your profile so BeU can build today's action plan.",
        priorityActions: [],
        realTimeNudges: [],
        supplementReminders: [],
        healthContextNotes: [],
        explanation: ["BeU needs your profile before it can personalize today's plan."],
        safetyNote: WELLNESS_DISCLAIMER,
        carbGuidance: "balanced carbs",
        calorieDirection: "Maintain",
        proteinLevel: "Moderate protein"
      };
    }

    const nutrition = this.nutritionTargetService.calculate(context, {
      strengthRecommended: false
    });
    const energyBalance = this.energyBalanceService.build(context, nutrition.calories);
    const activity = this.activityTargetService.build(context, energyBalance);
    const nutritionWithStrength = this.nutritionTargetService.calculate(context, {
      strengthRecommended: activity.strengthTraining.recommendation === "required"
    });

    const activeConditions = new Set(
      context.healthConditions.filter((item) => item.isActive).map((item) => item.conditionType)
    );

    const stepsCompleted = context.healthData.todaySteps ?? 0;
    const waterConsumed = roundToOneDecimal(context.nutritionProgress.waterConsumedTodayLiters);
    const progress = {
      caloriesConsumed: context.nutritionProgress.consumedCaloriesToday,
      caloriesRemaining: nutritionWithStrength.calories - context.nutritionProgress.consumedCaloriesToday,
      proteinConsumedGrams: roundToOneDecimal(context.nutritionProgress.consumedProteinTodayGrams),
      proteinRemainingGrams: roundToOneDecimal(nutritionWithStrength.proteinGrams - context.nutritionProgress.consumedProteinTodayGrams),
      stepsCompleted,
      stepsRemaining: Math.max(0, activity.steps - stepsCompleted),
      waterConsumedLiters: waterConsumed,
      waterRemainingLiters: roundToOneDecimal(Math.max(0, nutritionWithStrength.waterLiters - waterConsumed))
    };

    const supplementReminders = this.buildSupplementReminders(context);
    const healthContextNotes: string[] = [];
    let safetyNote = WELLNESS_DISCLAIMER;

    if (activeConditions.has("pcos")) {
      healthContextNotes.push("PCOS in your history — plan focuses on balanced meals, protein, and consistency.");
    }
    if (activeConditions.has("diabetes")) {
      safetyNote = "For diabetes-specific nutrition, please follow your clinician's advice.";
    }
    if (activeConditions.has("pregnancy")) {
      safetyNote = "Pregnancy nutrition needs should be discussed with a qualified healthcare professional.";
    }
    if (activeConditions.has("eating_disorder_history")) {
      safetyNote = "If food tracking feels stressful, consider using BeU without calorie targets.";
    }
    if (activeConditions.has("anemia")) {
      healthContextNotes.push("Prioritize balanced meals and follow clinician advice for iron-related needs.");
    }
    if (activeConditions.has("hypertension") || activeConditions.has("cholesterol") || activeConditions.has("thyroid")) {
      healthContextNotes.push("For condition-specific medical nutrition, please consult your healthcare provider.");
    }

    const priorityActions = this.buildPriorityActions(context, nutritionWithStrength, activity, progress, energyBalance, supplementReminders);
    const summary = this.buildSummary(context, nutritionWithStrength, activity, energyBalance);
    const explanation = [
      ...nutritionWithStrength.explanation,
      ...activity.explanation,
      `Today's readiness is ${context.readiness.status ?? "not available"}, so the plan uses a ${activity.strengthTraining.recommendation === "rest" ? "lighter" : "normal"} activity profile.`,
      "Apple Health active energy shapes daily activity burn, while workout calories are shown separately for context and are not double-counted."
    ];

    const plan: DailyPersonalizedActionPlan = {
      userId: context.userId,
      date,
      targets: {
        calories: nutrition.calories,
        proteinGrams: nutritionWithStrength.proteinGrams,
        waterLiters: nutritionWithStrength.waterLiters,
        steps: activity.steps,
        cardioMinutes: activity.cardioMinutes,
        strengthTraining: activity.strengthTraining
      },
      progress,
      energyBalance,
      planSummary: summary,
      priorityActions,
      realTimeNudges: [],
      supplementReminders,
      healthContextNotes,
      explanation,
      safetyNote,
      carbGuidance: nutritionWithStrength.carbGuidance,
      calorieDirection: nutritionWithStrength.calorieDirection,
      proteinLevel: nutritionWithStrength.proteinLevel
    };

    const intake: DailyIntake = {
      kcal: progress.caloriesConsumed,
      protein: progress.proteinConsumedGrams,
      waterLitres: progress.waterConsumedLiters,
      steps: progress.stepsCompleted
    };
    plan.realTimeNudges = this.nudgeEngine.buildNudges(plan, intake);
    return plan;
  }

  private buildSupplementReminders(context: PersonalizationContext): string[] {
    const band = currentTimeBand(new Date());
    const reminders: string[] = [];
    for (const supplement of context.supplements) {
      if (!supplement.isActive) {
        continue;
      }
      if (supplement.frequency !== "daily" && supplement.frequency !== "weekly") {
        continue;
      }
      if (!supplement.timeOfDay) {
        continue;
      }
      if (supplement.timeOfDay !== "with_meal" && supplement.timeOfDay !== band) {
        continue;
      }

      const suffix = TIME_BAND_TITLES[supplement.timeOfDay];
      reminders.push(`Take ${supplement.name}${suffix ? ` (${suffix})` : ""}.`);
      if (reminders.length >= 3) {
        break;
      }
    }
    return reminders;
  }

  private buildPriorityActions(
    context: PersonalizationContext,
    nutrition: ReturnType<NutritionTargetService["calculate"]>,
    activity: ReturnType<ActivityTargetService["build"]>,
    progress: DailyPersonalizedActionPlan["progress"],
    energyBalance: DailyEnergyBalance,
    supplementReminders: string[]
  ): DailyPlanPriorityAction[] {
    const actions: DailyPlanPriorityAction[] = [];
    const goal = context.profile?.goalType ?? "general_wellness";
    const activeConditions = new Set(
      context.healthConditions.filter((item) => item.isActive).map((item) => item.conditionType)
    );

    if (context.readiness.status === "low") {
      actions.push({
        title: "Protect recovery",
        description: "Keep activity light, keep meals steady, and protect sleep tonight.",
        priority: "high",
        category: "recovery"
      });
    }

    if (energyBalance.remainingBurnTarget > 250 && context.readiness.status !== "low") {
      actions.push({
        title: "Add a 25-minute walk",
        description: "You are behind today's calorie burn target, and walking is the cleanest way to close the gap.",
        priority: "high",
        category: "activity"
      });
    }

    if (progress.proteinRemainingGrams > 30) {
      actions.push({
        title: `Hit ${nutrition.proteinGrams}g protein`,
        description: "Make the next meal protein-led and keep the structure simple.",
        priority: "high",
        category: "nutrition"
      });
    }

    if (activity.strengthTraining.recommendation === "required") {
      actions.push({
        title: `Complete ${activity.strengthTraining.durationMinutes} minutes of strength`,
        description: "Keep the session controlled and consistent with today's readiness.",
        priority: "high",
        category: "activity"
      });
    }

    if (energyBalance.activeEnergyBurned > (context.healthData.sevenDayAvgActiveEnergyKcal ?? 0) && (context.healthData.sevenDayAvgActiveEnergyKcal ?? 0) > 0) {
      actions.push({
        title: "Keep food balanced",
        description: "You've burned more than usual today, so keep meals balanced and protein-led.",
        priority: "medium",
        category: "nutrition"
      });
    }

    if (energyBalance.workoutEnergyBurned > 250) {
      actions.push({
        title: "Refuel with protein",
        description: "Workout energy burn was high, so the next meal should lead with protein.",
        priority: "medium",
        category: "nutrition"
      });
    }

    if (progress.caloriesConsumed > nutrition.calories && energyBalance.remainingBurnTarget > 150) {
      actions.push({
        title: "Choose a lighter dinner and a short walk",
        description: "Calories are above target and activity is still behind, so keep the evening simple.",
        priority: "high",
        category: "nutrition"
      });
    } else if (progress.stepsRemaining > 1500 && goal === "fat_loss" && energyBalance.remainingBurnTarget > 0) {
      actions.push({
        title: `Close the ${progress.stepsRemaining.toLocaleString()}-step gap`,
        description: "A short walk can move the day closer to target without overcomplicating it.",
        priority: "medium",
        category: "activity"
      });
    }

    actions.push({
      title: `Drink ${nutrition.waterLiters.toFixed(1)}L water`,
      description: "Spread fluids through the day instead of catching up late.",
      priority: "medium",
      category: "hydration"
    });

    if (activeConditions.has("pcos")) {
      actions.unshift({
        title: "Keep meals balanced",
        description: "Use protein, fiber, and steady eating windows to keep the day consistent.",
        priority: "high",
        category: "nutrition"
      });
    }

    if (supplementReminders.length > 0) {
      actions.push({
        title: "Follow your saved supplement routine",
        description: supplementReminders[0] ?? "Keep your usual supplement routine in mind.",
        priority: "low",
        category: "supplement"
      });
    }

    if (activeConditions.has("pregnancy") || activeConditions.has("eating_disorder_history")) {
      return actions
        .filter((item) => !item.title.toLowerCase().includes("gap"))
        .slice(0, 5);
    }

    return actions.slice(0, 5);
  }

  private buildSummary(
    context: PersonalizationContext,
    nutrition: ReturnType<NutritionTargetService["calculate"]>,
    activity: ReturnType<ActivityTargetService["build"]>,
    energyBalance: DailyEnergyBalance
  ): string {
    const activeConditions = new Set(
      context.healthConditions.filter((item) => item.isActive).map((item) => item.conditionType)
    );

    if (activeConditions.has("eating_disorder_history")) {
      return "Today is a consistency-focused day. Prioritize regular meals, hydration, and manageable movement.";
    }
    if (activity.strengthTraining.recommendation === "rest") {
      return "Today is a recovery-focused day. Prioritize protein, hydration, and light movement.";
    }
    if (energyBalance.remainingBurnTarget <= 0) {
      return "Nutrition and activity are on track today. Keep meals balanced and let extra movement stay optional.";
    }
    if (context.readiness.status === "high") {
      return "You're ready for a normal training day. Aim for strength work and hit your protein target.";
    }
    if (nutrition.calorieDirection == "Slight deficit") {
      return "Stay in a moderate deficit today, while keeping protein and recovery habits steady.";
    }
    if (energyBalance.remainingBurnTarget > 250) {
      return "Activity is still behind today, so use a short walk, steady meals, and protein to keep the day moving the right way.";
    }
    return "Keep the day balanced with steady meals, fluids, and practical movement.";
  }
}
