import { HealthSummaryRepository } from "../../repositories/healthSummaryRepository.js";
import { NutritionRepository } from "../../repositories/nutritionRepository.js";
import { buildDailyNutritionProgress } from "../nutritionSupport.js";
import { currentIsoDay, lastNDaysInclusive, shiftIsoDay } from "../../utils/date.js";
import type { HealthSummary, MealLog, UserNutritionProfile } from "../../types/health.js";
import type {
  ActivityLevel,
  EngineGoal,
  PersonalizationContext,
  ReadinessSnapshot,
  TrendDirection
} from "./actionPlanTypes.js";

function average(values: Array<number | null | undefined>): number | null {
  const filtered = values.filter((value): value is number => typeof value === "number" && Number.isFinite(value));
  if (filtered.length === 0) {
    return null;
  }
  return filtered.reduce((total, value) => total + value, 0) / filtered.length;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function inferActivityLevel(sevenDayAvgSteps: number | null): ActivityLevel | null {
  if (sevenDayAvgSteps === null) {
    return null;
  }
  if (sevenDayAvgSteps < 5000) {
    return "sedentary";
  }
  if (sevenDayAvgSteps < 7500) {
    return "light";
  }
  if (sevenDayAvgSteps < 10000) {
    return "moderate";
  }
  return "active";
}

function parseTimelineWeeks(value: string | null | undefined): number | null {
  if (!value) {
    return null;
  }
  const matched = value.match(/\d+/);
  if (!matched) {
    return null;
  }
  const parsed = Number.parseInt(matched[0], 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function goalTypeFromProfile(profile: UserNutritionProfile | null): EngineGoal {
  switch (profile?.goalType) {
    case "lose_weight":
      return "fat_loss";
    case "gain_muscle":
      return "muscle_gain";
    case "maintain_weight":
      return "maintain";
    default:
      return "general_wellness";
  }
}

function computeReadiness(summary: HealthSummary | null, sevenDaySummaries: HealthSummary[]): ReadinessSnapshot | null {
  if (!summary) {
    return null;
  }

  let score = 62;
  const reasons: string[] = [];

  const sevenDaySleep = average(sevenDaySummaries.map((item) => item.sleepHours > 0 ? item.sleepHours : null));
  const sevenDayHRV = average(sevenDaySummaries.map((item) => item.hrvMs));
  const sevenDayRHR = average(sevenDaySummaries.map((item) => item.restingHeartRateBpm));
  const sevenDaySteps = average(sevenDaySummaries.map((item) => item.steps > 0 ? item.steps : null));
  const sevenDayActiveEnergy = average(sevenDaySummaries.map((item) => item.activeEnergyKcal > 0 ? item.activeEnergyKcal : null));

  if (summary.sleepHours > 0) {
    if (summary.sleepHours < 6) {
      score -= 18;
      reasons.push("Sleep was short.");
    } else if (summary.sleepHours < 6.5) {
      score -= 10;
      reasons.push("Sleep was lighter than usual.");
    } else if (summary.sleepHours >= 8) {
      score += 10;
      reasons.push("Sleep was steady.");
    } else if (summary.sleepHours >= 7) {
      score += 5;
      reasons.push("Sleep supported a normal day.");
    }
  }

  if (summary.hrvMs !== null && sevenDayHRV !== null && sevenDayHRV > 0) {
    if (summary.hrvMs >= sevenDayHRV * 1.08) {
      score += 8;
      reasons.push("Recovery signals look steadier than your recent average.");
    } else if (summary.hrvMs <= sevenDayHRV * 0.92) {
      score -= 8;
      reasons.push("Recovery signals are a little softer than usual.");
    }
  }

  if (summary.restingHeartRateBpm !== null && sevenDayRHR !== null) {
    if (summary.restingHeartRateBpm <= sevenDayRHR - 1) {
      score += 6;
      reasons.push("Resting heart rate is calm for you.");
    } else if (summary.restingHeartRateBpm >= sevenDayRHR + 2) {
      score -= 7;
      reasons.push("Resting heart rate is a little elevated.");
    }
  }

  if (sevenDaySteps !== null && sevenDaySteps > 0) {
    if (summary.steps >= sevenDaySteps * 0.95) {
      score += 3;
      reasons.push("Movement is close to your recent rhythm.");
    } else if (summary.steps < sevenDaySteps * 0.6) {
      score -= 4;
      reasons.push("Movement is lighter than your recent rhythm.");
    }
  }

  if (sevenDayActiveEnergy !== null && sevenDayActiveEnergy > 0 && summary.activeEnergyKcal > sevenDayActiveEnergy * 1.4 && summary.sleepHours < 6.5) {
    score -= 6;
    reasons.push("Low sleep plus higher activity points to a lighter day.");
  }

  score = clamp(Math.round(score), 28, 96);

  const status: ReadinessSnapshot["status"] =
    score >= 75 ? "high" : score >= 55 ? "moderate" : "low";
  const oneLineMessage =
    status === "high"
      ? "You're well-rested — push a little today"
      : status === "moderate"
        ? "Steady energy — keep things consistent"
        : "Honor recovery — keep activity light";

  return {
    score,
    status,
    oneLineMessage,
    reasons: reasons.length > 0 ? reasons : ["Recent movement and recovery signals are shaping today's plan."]
  };
}

function computeTrendDirection(scores: number[]): TrendDirection | null {
  if (scores.length < 7) {
    return null;
  }
  const previous = scores.slice(0, 4);
  const recent = scores.slice(4);
  const previousAverage = average(previous);
  const recentAverage = average(recent);
  if (previousAverage === null || recentAverage === null) {
    return null;
  }
  const delta = recentAverage - previousAverage;
  if (delta >= 5) {
    return "improving";
  }
  if (delta <= -5) {
    return "declining";
  }
  return "stable";
}

function approximateStrengthSessions(summaries: HealthSummary[]): number {
  return summaries.filter((item) => item.workoutCount > 0 && item.workoutMinutes >= 25).length;
}

function approximateCardioSessions(summaries: HealthSummary[]): number {
  return summaries.filter((item) => item.steps >= 7000 || item.activeEnergyKcal >= 250 || item.workoutMinutes >= 20).length;
}

export class PersonalizationContextBuilder {
  constructor(
    private readonly nutritionRepository = new NutritionRepository(),
    private readonly healthSummaryRepository = new HealthSummaryRepository()
  ) {}

  build(userId: string, date: string = currentIsoDay()): PersonalizationContext {
    const profile = this.nutritionRepository.getProfile(userId);
    const today = this.healthSummaryRepository.getByUserAndDate(userId, date);
    const eightDayWindow = this.healthSummaryRepository.listByUser(userId, 8);
    const sevenDayEnd = date;
    const sevenDayStart = shiftIsoDay(sevenDayEnd, -6);
    const sevenDaySummaries = eightDayWindow.filter((item) => item.date >= sevenDayStart && item.date <= sevenDayEnd);
    const yesterday = this.healthSummaryRepository.getByUserAndDate(userId, shiftIsoDay(date, -1));
    const todaysMeals = this.nutritionRepository.listMealLogsByDate(userId, date);
    const weeklyMeals = this.nutritionRepository.listMealLogsByRange(userId, sevenDayStart, sevenDayEnd);
    const todaysWaterLogs = this.nutritionRepository.listWaterLogsByDate(userId, date);
    const weeklyWaterLogs = this.nutritionRepository.listWaterLogsByRange(userId, sevenDayStart, sevenDayEnd);
    const supplements = this.nutritionRepository.listSupplements(userId);
    const conditions = this.nutritionRepository.listHealthConditions(userId);

    const readinessSnapshots = lastNDaysInclusive(date, 7)
      .map((day) => computeReadiness(
        this.healthSummaryRepository.getByUserAndDate(userId, day),
        sevenDaySummaries
      ))
      .filter((item): item is ReadinessSnapshot => item !== null);

    const currentReadiness = computeReadiness(today, sevenDaySummaries);
    const dailyProgress = profile
      ? buildDailyNutritionProgress(userId, date, profile, todaysMeals)
      : null;
    const sevenDayAvgSteps = average(sevenDaySummaries.map((item) => item.steps > 0 ? item.steps : null));
    const sevenDayAvgActiveEnergy = average(sevenDaySummaries.map((item) => item.activeEnergyKcal > 0 ? item.activeEnergyKcal : null));
    const sevenDayAvgBasalEnergy = average(sevenDaySummaries.map((item) => item.basalEnergyKcal));
    const sevenDayAvgWorkoutEnergy = average(sevenDaySummaries.map((item) => item.workoutEnergyKcal > 0 ? item.workoutEnergyKcal : null));
    const sevenDayAvgSleep = average(sevenDaySummaries.map((item) => item.sleepHours > 0 ? item.sleepHours : null));
    const sevenDayAvgHRV = average(sevenDaySummaries.map((item) => item.hrvMs));
    const sevenDayAvgRHR = average(sevenDaySummaries.map((item) => item.restingHeartRateBpm));

    return {
      userId,
      profile: profile ? {
        gender: profile.sex ?? null,
        age: profile.age ?? null,
        heightCm: profile.heightCm ?? null,
        currentWeightKg: profile.currentWeightKg ?? null,
        targetWeightKg: profile.targetWeightKg ?? null,
        goalType: goalTypeFromProfile(profile),
        targetTimelineWeeks: parseTimelineWeeks(profile.targetTimeline),
        activityLevel: inferActivityLevel(sevenDayAvgSteps)
      } : null,
      healthData: {
        todaySteps: today?.steps ?? null,
        sevenDayAvgSteps,
        todayActiveEnergyKcal: today?.activeEnergyKcal ?? null,
        sevenDayAvgActiveEnergyKcal: sevenDayAvgActiveEnergy,
        todayBasalEnergyKcal: today?.basalEnergyKcal ?? null,
        sevenDayAvgBasalEnergyKcal: sevenDayAvgBasalEnergy,
        todayWorkoutEnergyKcal: today?.workoutEnergyKcal ?? null,
        sevenDayAvgWorkoutEnergyKcal: sevenDayAvgWorkoutEnergy,
        todaySleepHours: today?.sleepHours && today.sleepHours > 0 ? today.sleepHours : null,
        sevenDayAvgSleepHours: sevenDayAvgSleep,
        todayHRV: today?.hrvMs ?? null,
        sevenDayAvgHRV,
        todayRestingHeartRate: today?.restingHeartRateBpm ?? null,
        sevenDayAvgRestingHeartRate: sevenDayAvgRHR,
        workoutToday: (today?.workoutCount ?? 0) > 0 || (today?.workoutMinutes ?? 0) > 0,
        workoutYesterday: (yesterday?.workoutCount ?? 0) > 0 || (yesterday?.workoutMinutes ?? 0) > 0,
        workoutsLast7Days: sevenDaySummaries.reduce((total, item) => total + item.workoutCount, 0),
        strengthSessionsLast7Days: approximateStrengthSessions(sevenDaySummaries),
        cardioSessionsLast7Days: approximateCardioSessions(sevenDaySummaries),
        sourceSummaries: sevenDaySummaries
      },
      readiness: {
        todayScore: currentReadiness?.score ?? null,
        status: currentReadiness?.status ?? null,
        oneLineMessage: currentReadiness?.oneLineMessage ?? "Activity and recovery signals will shape your plan when available.",
        sevenDayScores: readinessSnapshots.map((item) => item.score),
        trendDirection: computeTrendDirection(readinessSnapshots.map((item) => item.score)),
        topReasons: currentReadiness?.reasons ?? []
      },
      nutritionProgress: {
        consumedCaloriesToday: dailyProgress?.consumedCalories ?? 0,
        consumedProteinTodayGrams: dailyProgress?.consumedProteinGrams ?? 0,
        consumedCarbsTodayGrams: dailyProgress?.consumedCarbsGrams ?? 0,
        consumedFatTodayGrams: dailyProgress?.consumedFatGrams ?? 0,
        mealsLoggedToday: todaysMeals.length,
        lastMealTime: todaysMeals.length > 0 ? todaysMeals[todaysMeals.length - 1]?.createdAt ?? null : null,
        waterConsumedTodayLiters: todaysWaterLogs.reduce((total, entry) => total + entry.litres, 0)
      },
      supplements: supplements.map((item) => ({
        name: item.name,
        dosage: item.dosage ?? null,
        frequency: item.frequency,
        timeOfDay: item.timeOfDay ?? null,
        isActive: item.isActive
      })),
      healthConditions: conditions.map((item) => ({
        conditionType: item.conditionType,
        isActive: item.isActive,
        notes: item.notes ?? null
      })),
      preferences: {
        dietPreference: null,
        preferredWorkoutDays: [],
        dislikedFoods: []
      },
      profileRecord: profile,
      todaySummary: today,
      sevenDaySummaries,
      todaysMeals,
      weeklyMeals,
      todaysWaterLogs,
      weeklyWaterLogs,
      onboardingRequired: profile === null
    };
  }
}
