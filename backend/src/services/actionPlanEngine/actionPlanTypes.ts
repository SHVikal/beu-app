import type {
  ConditionType,
  HealthCondition,
  HealthSummary,
  MealLog,
  Supplement,
  SupplementTime,
  UserNutritionProfile,
  WaterLog
} from "../../types/health.js";

export type EngineGoal = "fat_loss" | "muscle_gain" | "maintain" | "general_wellness";
export type ActivityLevel = "sedentary" | "light" | "moderate" | "active";
export type ReadinessStatus = "high" | "moderate" | "low";
export type TrendDirection = "improving" | "declining" | "stable";
export type StrengthRecommendationType = "required" | "optional" | "rest";
export type StrengthIntensity = "light" | "moderate" | "high";
export type PriorityLevel = "high" | "medium" | "low";
export type PlanCategory = "nutrition" | "hydration" | "activity" | "recovery" | "supplement";
export type NudgeUrgency = "low" | "medium" | "high";
export type NudgeTone = "soft" | "alert" | "win";
export type MealSource = "photo" | "text";

export interface PersonalizationContextProfile {
  gender: UserNutritionProfile["sex"] | null;
  age: number | null;
  heightCm: number | null;
  currentWeightKg: number | null;
  targetWeightKg: number | null;
  goalType: EngineGoal;
  targetTimelineWeeks: number | null;
  activityLevel: ActivityLevel | null;
}

export interface PersonalizationContextHealthData {
  todaySteps: number | null;
  sevenDayAvgSteps: number | null;
  todayActiveEnergyKcal: number | null;
  sevenDayAvgActiveEnergyKcal: number | null;
  todayBasalEnergyKcal: number | null;
  sevenDayAvgBasalEnergyKcal: number | null;
  todayWorkoutEnergyKcal: number | null;
  sevenDayAvgWorkoutEnergyKcal: number | null;
  todaySleepHours: number | null;
  sevenDayAvgSleepHours: number | null;
  todayHRV: number | null;
  sevenDayAvgHRV: number | null;
  todayRestingHeartRate: number | null;
  sevenDayAvgRestingHeartRate: number | null;
  workoutToday: boolean;
  workoutYesterday: boolean;
  workoutsLast7Days: number | null;
  strengthSessionsLast7Days: number | null;
  cardioSessionsLast7Days: number | null;
  sourceSummaries: HealthSummary[];
}

export interface PersonalizationContextReadiness {
  todayScore: number | null;
  status: ReadinessStatus | null;
  oneLineMessage: string;
  sevenDayScores: number[];
  trendDirection: TrendDirection | null;
  topReasons: string[];
}

export interface PersonalizationContextNutritionProgress {
  consumedCaloriesToday: number;
  consumedProteinTodayGrams: number;
  consumedCarbsTodayGrams: number;
  consumedFatTodayGrams: number;
  mealsLoggedToday: number;
  lastMealTime: string | null;
  waterConsumedTodayLiters: number;
}

export interface PersonalizationContextPreferences {
  dietPreference: string | null;
  preferredWorkoutDays: string[];
  dislikedFoods: string[];
}

export interface PersonalizationContext {
  userId: string;
  profile: PersonalizationContextProfile | null;
  healthData: PersonalizationContextHealthData;
  readiness: PersonalizationContextReadiness;
  nutritionProgress: PersonalizationContextNutritionProgress;
  supplements: Array<{
    name: string;
    dosage: string | null;
    frequency: Supplement["frequency"] | null;
    timeOfDay: Supplement["timeOfDay"] | null;
    isActive: boolean;
  }>;
  healthConditions: Array<{
    conditionType: ConditionType;
    isActive: boolean;
    notes: string | null;
  }>;
  preferences: PersonalizationContextPreferences;
  profileRecord: UserNutritionProfile | null;
  todaySummary: HealthSummary | null;
  sevenDaySummaries: HealthSummary[];
  todaysMeals: MealLog[];
  weeklyMeals: MealLog[];
  todaysWaterLogs: WaterLog[];
  weeklyWaterLogs: WaterLog[];
  onboardingRequired: boolean;
}

export interface StrengthTrainingPlan {
  recommendation: StrengthRecommendationType;
  durationMinutes: number;
  intensity: StrengthIntensity;
  focus?: "full_body" | "upper_body" | "lower_body" | "mobility" | "recovery";
}

export interface DailyPlanTargets {
  calories: number;
  proteinGrams: number;
  waterLiters: number;
  steps: number;
  cardioMinutes: number;
  strengthTraining: StrengthTrainingPlan;
}

export interface DailyEnergyBalance {
  date: string;
  calorieIntakeTarget: number;
  caloriesConsumed: number;
  activeEnergyBurned: number;
  basalEnergyBurned: number | null;
  workoutEnergyBurned: number;
  estimatedTotalBurn: number;
  dailyBurnTarget: number;
  remainingBurnTarget: number;
  netCalories: number;
  targetNetCalories: number | null;
  energyBalanceStatus: "under_target" | "on_track" | "over_consumed" | "under_burned" | "balanced";
  message: string;
}

export interface DailyPlanProgress {
  caloriesConsumed: number;
  caloriesRemaining: number;
  proteinConsumedGrams: number;
  proteinRemainingGrams: number;
  stepsCompleted: number;
  stepsRemaining: number;
  waterConsumedLiters: number;
  waterRemainingLiters: number;
}

export interface DailyPlanPriorityAction {
  title: string;
  description: string;
  priority: PriorityLevel;
  category: PlanCategory;
}

export interface DailyPlanNudge {
  id: string;
  message: string;
  reason: string;
  category: PlanCategory;
  urgency: NudgeUrgency;
  tone: NudgeTone;
  action?: string;
}

export interface DailyPersonalizedActionPlan {
  userId: string;
  date: string;
  onboardingRequired?: boolean;
  targets: DailyPlanTargets;
  progress: DailyPlanProgress;
  energyBalance: DailyEnergyBalance;
  planSummary: string;
  priorityActions: DailyPlanPriorityAction[];
  realTimeNudges: DailyPlanNudge[];
  supplementReminders: string[];
  healthContextNotes: string[];
  explanation: string[];
  safetyNote: string;
  carbGuidance: string;
  calorieDirection: string;
  proteinLevel: string;
}

export interface WeeklyEnergySummary {
  avgCaloriesConsumed: number;
  avgCalorieIntakeTarget: number;
  avgEstimatedBurn: number;
  avgBurnTarget: number;
  totalWorkoutEnergyBurned: number;
  daysBurnTargetMet: number;
  daysIntakeTargetMet: number;
  energyTrend: TrendDirection;
  message: string;
}

export interface WeeklyPlanTargets {
  avgDailyCalories: number;
  avgDailyProteinGrams: number;
  totalStrengthSessions: number;
  totalCardioMinutes: number;
  avgDailySteps: number;
  avgDailyWaterLiters: number;
}

export interface WeeklyPersonalizedActionPlan {
  userId: string;
  weekStartDate: string;
  weekEndDate: string;
  onboardingRequired?: boolean;
  weeklyTargets: WeeklyPlanTargets;
  weeklyEnergySummary: WeeklyEnergySummary;
  weeklyFocus: string[];
  weeklyFeedback: {
    readinessTrend: string;
    calorieConsistency: string;
    proteinConsistency: string;
    activityConsistency: string;
    recoveryConsistency: string;
  };
  recommendedAdjustments: Array<{
    title: string;
    description: string;
    reason: string;
  }>;
  explanation: string[];
  safetyNote: string;
}

export interface WeeklyInsightsResponse {
  userId: string;
  weekStartDate: string;
  weekEndDate: string;
  averageReadiness: number | null;
  consistencyScore: number;
  trendDirection: TrendDirection;
  cards: Array<{
    kicker: string;
    sentence: string;
  }>;
  actions: Array<{
    title: string;
    description: string;
  }>;
  disclaimer: string;
}

export interface DailyIntake {
  kcal: number;
  protein: number;
  waterLitres: number;
  steps: number;
}

export interface ReadinessSnapshot {
  score: number;
  status: ReadinessStatus;
  oneLineMessage: string;
  reasons: string[];
}

export interface PlanMealLogRequest {
  userId: string;
  source: MealSource;
  text?: string | null;
  image?: string | null;
  mealSlot: "breakfast" | "lunch" | "dinner" | "snack";
  items: MealLog["items"];
  date: string;
}

export interface DailyPlanLogResponse {
  mealLog: MealLog;
  progress: DailyPlanProgress;
  nudges: DailyPlanNudge[];
}

export const WELLNESS_DISCLAIMER =
  "BeU provides general wellness guidance only and does not replace medical advice.";

export const FORBIDDEN_PLAN_SUBSTRINGS = [
  "diagnose",
  "prescribe",
  "dosage",
  "start taking",
  "stop taking",
  "interaction",
  "insulin",
  "treat"
];

export const TIME_BAND_TITLES: Record<Exclude<SupplementTime, null>, string> = {
  morning: "morning",
  afternoon: "afternoon",
  evening: "evening",
  with_meal: "with a meal",
  before_bed: "before bed"
};
