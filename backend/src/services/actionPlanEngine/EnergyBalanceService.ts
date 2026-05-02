import type {
  DailyEnergyBalance,
  PersonalizationContext
} from "./actionPlanTypes.js";

function inferActivityMultiplier(steps: number | null): number {
  if (steps === null) return 1.55;
  if (steps < 5000) return 1.2;
  if (steps < 7500) return 1.375;
  if (steps < 10000) return 1.55;
  return 1.725;
}

export class EnergyBalanceService {
  build(context: PersonalizationContext, calorieTarget: number): DailyEnergyBalance {
    const weightKg = context.profile?.currentWeightKg ?? context.profileRecord?.currentWeightKg ?? null;
    const heightCm = context.profile?.heightCm ?? context.profileRecord?.heightCm ?? null;
    const age = context.profile?.age ?? 30;
    const sex = context.profile?.gender ?? context.profileRecord?.sex ?? null;

    const estimatedBmr = this.calculateBmr(weightKg, heightCm, age, sex);
    const activeEnergyBurned = Math.round(context.healthData.todayActiveEnergyKcal ?? 0);
    const basalEnergyBurned = context.healthData.todayBasalEnergyKcal === null ? null : Math.round(context.healthData.todayBasalEnergyKcal);
    const workoutEnergyBurned = Math.round(context.healthData.todayWorkoutEnergyKcal ?? 0);
    const estimatedTotalBurn = Math.round((basalEnergyBurned ?? estimatedBmr) + activeEnergyBurned);
    const activityMultiplier = inferActivityMultiplier(context.profile?.activityLevel ? null : context.healthData.sevenDayAvgSteps);
    const dailyBurnTarget = Math.round(estimatedBmr * (
      context.profile?.activityLevel === "sedentary" ? 1.2 :
        context.profile?.activityLevel === "light" ? 1.375 :
          context.profile?.activityLevel === "active" ? 1.725 : activityMultiplier
    ));
    const caloriesConsumed = context.nutritionProgress.consumedCaloriesToday;
    const remainingBurnTarget = Math.max(0, dailyBurnTarget - estimatedTotalBurn);
    const netCalories = caloriesConsumed - estimatedTotalBurn;
    const targetNetCalories = calorieTarget - dailyBurnTarget;

    const status = this.statusFor(caloriesConsumed, calorieTarget, remainingBurnTarget);
    const message = this.messageFor(status);

    return {
      date: context.todaySummary?.date ?? new Date().toISOString().slice(0, 10),
      calorieIntakeTarget: calorieTarget,
      caloriesConsumed,
      activeEnergyBurned,
      basalEnergyBurned,
      workoutEnergyBurned,
      estimatedTotalBurn,
      dailyBurnTarget,
      remainingBurnTarget,
      netCalories,
      targetNetCalories,
      energyBalanceStatus: status,
      message
    };
  }

  private calculateBmr(
    weightKg: number | null,
    heightCm: number | null,
    age: number,
    sex: string | null
  ): number {
    if (weightKg === null || heightCm === null) {
      return Math.round((age * 12) + 1400);
    }

    const male = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    const female = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    if (sex === "male") return Math.round(male);
    if (sex === "female") return Math.round(female);
    return Math.round((male + female) / 2);
  }

  private statusFor(
    caloriesConsumed: number,
    calorieTarget: number,
    remainingBurnTarget: number
  ): DailyEnergyBalance["energyBalanceStatus"] {
    if (caloriesConsumed > calorieTarget && remainingBurnTarget > 150) {
      return "over_consumed";
    }
    if (remainingBurnTarget <= 0 && caloriesConsumed <= calorieTarget) {
      return "balanced";
    }
    if (remainingBurnTarget <= 0) {
      return "on_track";
    }
    if (remainingBurnTarget > 250) {
      return "under_burned";
    }
    return "under_target";
  }

  private messageFor(status: DailyEnergyBalance["energyBalanceStatus"]): string {
    switch (status) {
      case "over_consumed":
        return "Calories are above target and activity is behind.";
      case "balanced":
        return "Nutrition and activity are both on track.";
      case "on_track":
        return "Burn target met. Extra movement is optional.";
      case "under_burned":
        return "Activity is behind today's burn target.";
      case "under_target":
        return "Burn is moving in the right direction, but there is still some room to close the gap.";
    }
  }
}
