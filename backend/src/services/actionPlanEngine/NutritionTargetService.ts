import type { PersonalizationContext } from "./actionPlanTypes.js";

function roundToOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

export class NutritionTargetService {
  calculate(context: PersonalizationContext, options: { strengthRecommended: boolean }): {
    calories: number;
    proteinGrams: number;
    waterLiters: number;
    carbGuidance: string;
    calorieDirection: string;
    proteinLevel: string;
    explanation: string[];
  } {
    const profile = context.profile;
    const goal = profile?.goalType ?? "general_wellness";
    const weightKg = profile?.currentWeightKg ?? context.profileRecord?.currentWeightKg ?? null;
    const heightCm = profile?.heightCm ?? context.profileRecord?.heightCm ?? null;
    const age = profile?.age ?? 30;
    const explanations: string[] = [];
    if ((profile?.age ?? null) === null) {
      explanations.push("Age was missing, so BeU used 30 as a planning fallback.");
    }

    const minCalories =
      profile?.gender === "female" ? 1200 :
        profile?.gender === "male" ? 1500 : 1300;

    let calorieDirection =
      goal === "fat_loss" ? "Slight deficit" :
        goal === "muscle_gain" ? "Slight surplus" : "Maintain";
    let carbGuidance =
      goal === "fat_loss" ? "keep carbs steadier later in the day" :
        goal === "muscle_gain" ? "carbs around training can help support recovery" :
          "balanced carbs across the day";

    let calories = context.profileRecord?.dailyCalorieTarget ?? minCalories;
    let proteinGrams = context.profileRecord?.dailyProteinTargetGrams ?? 100;

    if (weightKg !== null && heightCm !== null) {
      const maleBmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
      const femaleBmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      const bmr =
        profile?.gender === "male" ? maleBmr :
          profile?.gender === "female" ? femaleBmr :
            (maleBmr + femaleBmr) / 2;

      const activityLevel = profile?.activityLevel ?? "moderate";
      const activityMultiplier =
        activityLevel === "sedentary" ? 1.2 :
          activityLevel === "light" ? 1.375 :
            activityLevel === "active" ? 1.725 : 1.55;

      const tdee = bmr * activityMultiplier;
      calories = Math.round(
        goal === "fat_loss" ? tdee - 300 :
          goal === "muscle_gain" ? tdee + 250 : tdee
      );

      const timelineWeeks = profile?.targetTimelineWeeks ?? null;
      const targetWeightKg = profile?.targetWeightKg ?? null;
      if (goal === "fat_loss" && targetWeightKg !== null && timelineWeeks && timelineWeeks > 0) {
        const kgDifference = (weightKg ?? 0) - targetWeightKg;
        const weeklyChangeNeeded = kgDifference / timelineWeeks;
        if (weeklyChangeNeeded > 0.75) {
          calories = Math.max(calories, Math.round(tdee - 500));
          explanations.push("Your timeline looks aggressive, so BeU is using a safer moderate target.");
        }
      }

      const proteinMultiplier =
        goal === "fat_loss" ? 1.6 :
          goal === "muscle_gain" ? 1.8 :
            goal === "maintain" ? 1.4 : 1.2;
      proteinGrams = Math.round(weightKg * (proteinMultiplier + (options.strengthRecommended ? 0.1 : 0)));
      explanations.push("Your calorie target is based on your weight, height, goal, and activity level.");
      explanations.push(goal === "muscle_gain"
        ? "Protein is higher because your goal emphasizes building strength and recovery."
        : "Protein is set to support recovery and a steady meal structure.");
    } else {
      explanations.push("BeU used your saved targets because height or weight data was missing.");
    }

    if (goal === "fat_loss" && context.readiness.status === "low") {
      calorieDirection = "Maintain";
      calories = Math.max(calories, context.profileRecord?.dailyCalorieTarget ?? calories);
      explanations.push("Readiness is low, so BeU avoids a more aggressive deficit today.");
    }

    const activeConditions = new Set(
      context.healthConditions.filter((item) => item.isActive).map((item) => item.conditionType)
    );

    if (activeConditions.has("pregnancy")) {
      calories = Math.max(calories, context.profileRecord?.dailyCalorieTarget ?? calories);
      calorieDirection = "Maintain";
    }

    if (activeConditions.has("eating_disorder_history")) {
      calorieDirection = "Maintain";
    }

    if (activeConditions.has("diabetes")) {
      carbGuidance = "keep carbs steady and balanced through the day";
    }

    if (activeConditions.has("pcos")) {
      carbGuidance = "balanced meals with protein and fiber can support consistency";
      explanations.push("PCOS is in your health history, so the plan keeps energy guidance moderate and consistent.");
    }

    calories = Math.max(calories, minCalories);
    const proteinLevel = proteinGrams >= 140 ? "High protein" : "Moderate protein";

    const todayEnergy = context.healthData.todayActiveEnergyKcal ?? 0;
    const yesterdayEnergy = context.sevenDaySummaries.at(-2)?.activeEnergyKcal ?? 0;
    const sevenDayAvgEnergy = context.healthData.sevenDayAvgActiveEnergyKcal ?? 0;

    let waterLiters = Math.max(2, Math.min(4, (weightKg ?? 70) * 0.035));
    if (sevenDayAvgEnergy > 0 && (todayEnergy > sevenDayAvgEnergy * 1.2 || yesterdayEnergy > sevenDayAvgEnergy * 1.2)) {
      waterLiters += 0.3;
    }
    if (context.healthData.workoutToday || context.healthData.workoutYesterday) {
      waterLiters += 0.3;
    }

    return {
      calories,
      proteinGrams,
      waterLiters: roundToOneDecimal(Math.max(2, Math.min(4, waterLiters))),
      carbGuidance,
      calorieDirection,
      proteinLevel,
      explanation: explanations
    };
  }
}
