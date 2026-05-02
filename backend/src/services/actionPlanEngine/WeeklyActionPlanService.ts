import { currentIsoDay, shiftIsoDay } from "../../utils/date.js";
import type {
  DailyPersonalizedActionPlan,
  PersonalizationContext,
  WeeklyInsightsResponse,
  WeeklyPersonalizedActionPlan
} from "./actionPlanTypes.js";
import { WELLNESS_DISCLAIMER } from "./actionPlanTypes.js";

function average(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }
  return values.reduce((total, value) => total + value, 0) / values.length;
}

export class WeeklyActionPlanService {
  buildWeeklyPlan(context: PersonalizationContext, dailyPlan: DailyPersonalizedActionPlan): WeeklyPersonalizedActionPlan {
    const weekEndDate = currentIsoDay();
    const weekStartDate = shiftIsoDay(weekEndDate, -6);
    const summaries = context.sevenDaySummaries;
    const readinessScores = context.readiness.sevenDayScores;
    const avgSleep = average(summaries.map((item) => item.sleepHours).filter((value) => value > 0));
    const avgSteps = Math.round(average(summaries.map((item) => item.steps)));
    const avgBurn = Math.round(average(summaries.map((item) => item.estimatedTotalBurnKcal)));
    const totalWorkoutEnergyBurned = Math.round(summaries.reduce((total, item) => total + item.workoutEnergyKcal, 0));
    const avgWater = Math.round((context.weeklyWaterLogs.reduce((total, item) => total + item.litres, 0) / 7) * 10) / 10;

    const goal = context.profile?.goalType ?? "general_wellness";
    const weeklyTargets = {
      avgDailyCalories: dailyPlan.targets.calories,
      avgDailyProteinGrams: dailyPlan.targets.proteinGrams,
      totalStrengthSessions: goal === "muscle_gain" ? 4 : goal === "fat_loss" ? 3 : 2,
      totalCardioMinutes: goal === "fat_loss" ? 135 : goal === "muscle_gain" ? 75 : 105,
      avgDailySteps: dailyPlan.targets.steps,
      avgDailyWaterLiters: dailyPlan.targets.waterLiters
    };

    const mealDays = new Map<string, number>();
    const proteinDaysHit = new Set<string>();
    const calorieDaysNearTarget = new Set<string>();

    for (const meal of context.weeklyMeals) {
      mealDays.set(meal.date, (mealDays.get(meal.date) ?? 0) + meal.totalCalories);
    }
    for (const [date, calories] of mealDays) {
      if (Math.abs(calories - weeklyTargets.avgDailyCalories) <= 250) {
        calorieDaysNearTarget.add(date);
      }
    }
    const proteinByDay = new Map<string, number>();
    for (const meal of context.weeklyMeals) {
      proteinByDay.set(meal.date, (proteinByDay.get(meal.date) ?? 0) + meal.totalProteinGrams);
    }
    for (const [date, protein] of proteinByDay) {
      if (protein >= weeklyTargets.avgDailyProteinGrams) {
        proteinDaysHit.add(date);
      }
    }

    const stepDaysHit = summaries.filter((item) => item.steps >= weeklyTargets.avgDailySteps).length;
    const daysBurnTargetMet = summaries.filter((item) => item.estimatedTotalBurnKcal >= dailyPlan.energyBalance.dailyBurnTarget).length;
    const readinessTrend = context.readiness.trendDirection ?? "stable";

    const weeklyFeedback = {
      readinessTrend,
      calorieConsistency: calorieDaysNearTarget.size >= 4 ? "steady" : "still finding a rhythm",
      proteinConsistency: proteinDaysHit.size >= 4 ? "consistent" : "protein has room to improve",
      activityConsistency: stepDaysHit >= 4 ? "consistent" : "movement was lighter than planned",
      recoveryConsistency: avgSleep >= 7 ? "sleep supported recovery" : "sleep trended a bit low"
    };

    const recommendedAdjustments: WeeklyPersonalizedActionPlan["recommendedAdjustments"] = [];
    if (readinessTrend === "declining") {
      recommendedAdjustments.push({
        title: "Lighten training demand",
        description: "Use a lighter training rhythm next week and protect sleep earlier in the day.",
        reason: "Recent readiness trended lower."
      });
    }
    if (proteinDaysHit.size < 4) {
      recommendedAdjustments.push({
        title: "Start meals with protein",
        description: "Plan one reliable protein-first meal earlier in the day.",
        reason: "Protein target was missed on more than three days."
      });
    }
    if (stepDaysHit < 3) {
      recommendedAdjustments.push({
        title: "Shrink the step jump",
        description: "Aim for a smaller daily step increase instead of chasing a large gap late in the day.",
        reason: "Step target was missed on most days."
      });
    }
    if (goal === "muscle_gain" && (context.healthData.strengthSessionsLast7Days ?? 0) < 3) {
      recommendedAdjustments.push({
        title: "Schedule strength earlier",
        description: "Block your next strength sessions in advance so they happen before the week gets crowded.",
        reason: "Strength sessions are behind your weekly target."
      });
    }
    if (recommendedAdjustments.length < 3) {
      recommendedAdjustments.push({
        title: "Plan meals earlier",
        description: "A little earlier meal planning can make calories and protein feel easier to hit consistently.",
        reason: "Consistency improves when meals are less reactive."
      });
    }

    const weeklyFocus = [
      "Keep the week simple with repeatable meals.",
      "Use movement targets that feel reachable day after day.",
      "Let recovery shape the harder days instead of forcing them."
    ];

    return {
      userId: context.userId,
      weekStartDate,
      weekEndDate,
      onboardingRequired: context.onboardingRequired,
      weeklyTargets,
      weeklyEnergySummary: {
        avgCaloriesConsumed: Math.round(average(Array.from(mealDays.values()))),
        avgCalorieIntakeTarget: dailyPlan.targets.calories,
        avgEstimatedBurn: avgBurn,
        avgBurnTarget: dailyPlan.energyBalance.dailyBurnTarget,
        totalWorkoutEnergyBurned,
        daysBurnTargetMet,
        daysIntakeTargetMet: calorieDaysNearTarget.size,
        energyTrend: daysBurnTargetMet >= 4 ? "improving" : daysBurnTargetMet <= 2 ? "declining" : "stable",
        message: `You met your burn target ${daysBurnTargetMet} out of 7 days.`
      },
      weeklyFocus,
      weeklyFeedback,
      recommendedAdjustments: recommendedAdjustments.slice(0, 3),
      explanation: [
        "Weekly targets are anchored to your current daily plan and recent activity.",
        "Recommendations change when readiness, protein consistency, or step consistency drift."
      ],
      safetyNote: context.healthConditions.some((item) => item.isActive)
        ? "Because you've added health history, use this as general wellness guidance and follow advice from a qualified healthcare professional for condition-specific needs."
        : WELLNESS_DISCLAIMER
    };
  }

  buildWeeklyInsights(context: PersonalizationContext, weeklyPlan: WeeklyPersonalizedActionPlan): WeeklyInsightsResponse {
    const readinessScores = context.readiness.sevenDayScores;
    const averageReadiness = readinessScores.length > 0
      ? Math.round(average(readinessScores))
      : null;
    const consistencyScore = Math.round(
      ((weeklyPlan.weeklyFeedback.calorieConsistency === "steady" ? 33 : 18) +
      (weeklyPlan.weeklyFeedback.proteinConsistency === "consistent" ? 33 : 18) +
      (weeklyPlan.weeklyFeedback.activityConsistency === "consistent" ? 34 : 18))
    );

    return {
      userId: context.userId,
      weekStartDate: weeklyPlan.weekStartDate,
      weekEndDate: weeklyPlan.weekEndDate,
      averageReadiness,
      consistencyScore,
      trendDirection: (context.readiness.trendDirection ?? "stable"),
      cards: [
        {
          kicker: "READINESS",
          sentence: context.readiness.trendDirection === "declining"
            ? "Recovery trended lower this week, so next week should stay a little lighter."
            : context.readiness.trendDirection === "improving"
              ? "Recovery trend improved this week, which supports a more normal routine."
              : "Recovery stayed steady across the week."
        },
        {
          kicker: "PROTEIN",
          sentence: weeklyPlan.weeklyFeedback.proteinConsistency === "consistent"
            ? "Protein stayed steady on most days."
            : "Protein was inconsistent, so a repeatable protein-first meal can help."
        },
        {
          kicker: "MOVEMENT",
          sentence: weeklyPlan.weeklyFeedback.activityConsistency === "consistent"
            ? "Movement stayed close to target on most days."
            : "Step targets were missed often enough that a smaller daily step lift makes sense."
        }
      ],
      actions: weeklyPlan.recommendedAdjustments.map((item) => ({
        title: item.title,
        description: item.description
      })),
      disclaimer: weeklyPlan.safetyNote
    };
  }
}
