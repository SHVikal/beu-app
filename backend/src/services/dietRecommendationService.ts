import { HealthSummaryService } from "./healthSummaryService.js";
import { UserGoalService } from "./userGoalService.js";
import { currentIsoDay, shiftIsoDay } from "../utils/date.js";
import type { DietRecommendation, HealthSummary, UserGoalType } from "../types/health.js";

interface RecommendationRequest {
  userId: string;
  date?: string;
}

export class DietRecommendationService {
  constructor(
    private readonly summaryService = new HealthSummaryService(),
    private readonly goalService = new UserGoalService()
  ) {}

  generate(request: RecommendationRequest): DietRecommendation {
    const date = request.date ?? currentIsoDay();
    const today = this.summaryService.getDaily(request.userId, date);
    if (!today) {
      throw new Error("No health summary found for the requested date.");
    }

    const goal = this.goalService.getByUserId(request.userId)?.goal ?? "general_wellness";
    const weekly = this.summaryService.getRange(request.userId, 7);
    const activeEnergyAverage =
      weekly.length > 0
        ? weekly.reduce((sum, item) => sum + item.activeEnergyKcal, 0) / weekly.length
        : today.activeEnergyKcal;

    const yesterday = this.summaryService.getDaily(request.userId, shiftIsoDay(date, -1));
    const recentWorkout = [today, yesterday].some(
      (summary) => (summary?.workoutCount ?? 0) > 0 || (summary?.workoutMinutes ?? 0) > 0
    );
    const lowSleep = today.sleepHours > 0 && today.sleepHours < 6.5;
    const highActivity = today.activeEnergyKcal > activeEnergyAverage;

    return buildRecommendation({
      today,
      goal,
      lowSleep,
      recentWorkout,
      highActivity,
      activeEnergyAverage
    });
  }
}

function buildRecommendation(input: {
  today: HealthSummary;
  goal: UserGoalType;
  lowSleep: boolean;
  recentWorkout: boolean;
  highActivity: boolean;
  activeEnergyAverage: number;
}): DietRecommendation {
  const signals: string[] = [];
  const mealSuggestions: string[] = [];
  const focusAreas: string[] = [];
  const today = input.today;
  const stepAnchor = today.steps;
  const sleepAnchor = today.sleepHours;
  const rhr = today.restingHeartRateBpm;
  const hrv = today.hrvMs;

  let suggestedCalorieDirection = "Keep calories near maintenance.";
  let proteinGuidance = "Aim for consistent protein across meals, roughly 25-30g per meal.";
  let carbGuidance = "Keep carbs balanced across the day and pair them with fiber-rich foods.";
  let hydrationGuidance = "Drink water consistently through the day and include electrolytes after long or sweaty sessions.";
  let recoveryNote = "Support recovery with regular meals, light movement, and a consistent sleep routine.";
  let nextBestAction = "Build your next plate around protein, produce, and a steady source of carbs.";

  if (input.recentWorkout) {
    signals.push("Recent workout detected");
    focusAreas.push("Recovery fueling");
    proteinGuidance = "Increase protein emphasis today, targeting a protein source at each meal and snack.";
    mealSuggestions.push(
      "Greek yogurt with berries and nuts",
      "Chicken, rice, and roasted vegetables",
      "Eggs with whole grain toast and fruit"
    );
    recoveryNote = "Because you trained recently, prioritize protein, fluids, and a meal or snack within a few hours of exercise.";
  }

  if (input.lowSleep) {
    signals.push("Sleep below 6.5 hours");
    focusAreas.push("Sleep recovery");
    suggestedCalorieDirection = "Avoid aggressive calorie restriction today. Favor steady, balanced intake.";
    carbGuidance = "Choose balanced carbs such as oats, potatoes, fruit, or rice instead of cutting carbs sharply after a short sleep night.";
    mealSuggestions.push("Balanced breakfast with protein, fruit, and whole grains");
    nextBestAction = "Keep meals regular today and avoid overcorrecting with a hard calorie cut after short sleep.";
  }

  if (input.highActivity) {
    signals.push("Active energy above 7-day average");
    focusAreas.push("Energy replacement");
    carbGuidance = "Activity is above your 7-day average, so include slightly more carbs around active periods for energy and recovery.";
    mealSuggestions.push("Rice bowl with lean protein, beans, and vegetables");
    nextBestAction = "Add a higher-carb meal near your most active part of the day to support recovery.";
  }

  if (stepAnchor >= 10000) {
    signals.push("High step count day");
    focusAreas.push("Daily movement support");
  } else if (stepAnchor > 0 && stepAnchor < 4000) {
    signals.push("Lower movement day");
    focusAreas.push("Appetite-aware structure");
  }

  if (rhr !== null && rhr <= 58) {
    signals.push("Resting heart rate on the lower side");
  } else if (rhr !== null && rhr >= 68) {
    signals.push("Resting heart rate elevated vs ideal wellness range");
    focusAreas.push("Stress and recovery");
  }

  if (hrv !== null && hrv < 35) {
    signals.push("HRV is on the lower side");
    focusAreas.push("Recovery capacity");
  } else if (hrv !== null && hrv >= 50) {
    signals.push("HRV looks resilient");
  }

  switch (input.goal) {
    case "fat_loss":
      signals.push("Goal: fat loss");
      focusAreas.push("Satiety");
      if (!input.lowSleep) {
        suggestedCalorieDirection = "Use a moderate calorie deficit, avoiding extreme restriction.";
      }
      proteinGuidance = "Keep protein high and steady to support fullness and lean mass.";
      mealSuggestions.push("High-protein salad with beans or chicken", "Soup and sandwich with fruit");
      nextBestAction = input.lowSleep
        ? "Prioritize a balanced, high-protein day first, then return to a modest calorie deficit once sleep normalizes."
        : "Aim for a modest calorie deficit with a protein-first breakfast and a fiber-rich lunch.";
      break;
    case "muscle_gain":
      signals.push("Goal: muscle gain");
      focusAreas.push("Performance nutrition");
      suggestedCalorieDirection = "Use a modest calorie surplus with steady meal timing.";
      proteinGuidance = "Increase total daily protein and include protein at all main meals plus one snack.";
      carbGuidance = "Center a larger share of carbs around workouts or active periods.";
      mealSuggestions.push("Oats with milk, banana, and nut butter", "Salmon, potatoes, and vegetables");
      nextBestAction = "Add one extra protein-and-carb feeding around training or earlier in the day.";
      break;
    case "maintenance":
      signals.push("Goal: maintenance");
      focusAreas.push("Consistency");
      suggestedCalorieDirection = "Keep calories steady and focus on routine consistency.";
      mealSuggestions.push("Protein-centered lunch with grains and vegetables");
      nextBestAction = "Repeat the meal pattern that feels easiest to sustain and keep hydration steady.";
      break;
    case "general_wellness":
    default:
      signals.push("Goal: general wellness");
      focusAreas.push("Foundations");
      suggestedCalorieDirection = "Keep intake balanced and sustainable rather than chasing aggressive changes.";
      mealSuggestions.push("Simple plate: protein, vegetables, whole grain, and healthy fat");
      nextBestAction = "Anchor today around hydration, protein at each meal, and one produce-heavy meal.";
      break;
  }

  if (mealSuggestions.length === 0) {
    mealSuggestions.push("Balanced meal with lean protein, vegetables, fiber-rich carbs, and water");
  }

  const insightTitle = chooseInsightTitle(input.goal, input.lowSleep, input.recentWorkout, input.highActivity);
  const personalizationNote = buildPersonalizationNote({
    steps: stepAnchor,
    sleepHours: sleepAnchor,
    restingHeartRateBpm: rhr,
    hrvMs: hrv,
    activeEnergyAverage: input.activeEnergyAverage,
    activeEnergyKcal: today.activeEnergyKcal
  });

  const summary = [
    `For ${today.date}, you logged ${today.steps} steps and ${Math.round(today.activeEnergyKcal)} active kcal.`,
    `Sleep was ${today.sleepHours.toFixed(1)} hours and workouts totaled ${Math.round(today.workoutMinutes)} minutes.`,
    `Recommendation is tuned for a ${input.goal.replace("_", " ")} goal.`
  ].join(" ");

  return {
    insightTitle,
    summary,
    personalizationNote,
    suggestedCalorieDirection,
    proteinGuidance,
    carbGuidance,
    hydrationGuidance,
    mealSuggestions: Array.from(new Set(mealSuggestions)),
    recoveryNote,
    nextBestAction,
    focusAreas: Array.from(new Set(focusAreas)),
    safetyNote:
      "This wellness guidance is informational only. It does not diagnose medical conditions or prescribe treatment. Consult a qualified healthcare professional for medical conditions, eating disorders, pregnancy, diabetes, or other special health needs.",
    signals
  };
}

function chooseInsightTitle(
  goal: UserGoalType,
  lowSleep: boolean,
  recentWorkout: boolean,
  highActivity: boolean
): string {
  if (lowSleep) {
    return "Recovery-first nutrition day";
  }
  if (recentWorkout && goal === "muscle_gain") {
    return "Build and refuel";
  }
  if (recentWorkout) {
    return "Refuel and recover";
  }
  if (highActivity) {
    return "Higher-output day";
  }
  if (goal === "fat_loss") {
    return "High-satiety fat-loss plan";
  }
  if (goal === "maintenance") {
    return "Steady maintenance day";
  }
  return "Balanced wellness plan";
}

function buildPersonalizationNote(input: {
  steps: number;
  sleepHours: number;
  restingHeartRateBpm: number | null;
  hrvMs: number | null;
  activeEnergyAverage: number;
  activeEnergyKcal: number;
}): string {
  const parts: string[] = [];

  if (input.steps >= 10000) {
    parts.push("Your movement volume is strong today");
  } else if (input.steps > 0 && input.steps < 4000) {
    parts.push("This looks like a lighter movement day");
  }

  if (input.sleepHours > 0) {
    parts.push(
      input.sleepHours < 6.5
        ? "sleep is low enough that recovery should shape the food plan"
        : "sleep is supportive enough to stay on plan"
    );
  }

  if (input.activeEnergyKcal > input.activeEnergyAverage) {
    parts.push("active burn is above your recent average");
  }

  if (input.restingHeartRateBpm !== null) {
    parts.push(`resting heart rate is ${Math.round(input.restingHeartRateBpm)} bpm`);
  }

  if (input.hrvMs !== null) {
    parts.push(`HRV is ${Math.round(input.hrvMs)} ms`);
  }

  if (parts.length === 0) {
    return "This recommendation is based on your recent movement, workouts, sleep, and available recovery metrics.";
  }

  if (parts.length === 1) {
    return `${parts[0].charAt(0).toUpperCase()}${parts[0].slice(1)}.`;
  }

  return `${parts[0].charAt(0).toUpperCase()}${parts[0].slice(1)}, and ${parts.slice(1).join(", ")}.`;
}
