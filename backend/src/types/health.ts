export interface HealthSummary {
  userId: string;
  date: string;
  steps: number;
  activeEnergyKcal: number;
  basalEnergyKcal: number | null;
  workoutCount: number;
  workoutMinutes: number;
  workoutEnergyKcal: number;
  totalEnergyBurnedKcal: number | null;
  estimatedTotalBurnKcal: number;
  sleepHours: number;
  restingHeartRateBpm: number | null;
  hrvMs: number | null;
  weightKg: number | null;
  heightCm: number | null;
  createdAt?: string;
  updatedAt?: string;
}

export type UserGoalType =
  | "fat_loss"
  | "muscle_gain"
  | "maintenance"
  | "general_wellness";

export interface UserGoal {
  userId: string;
  goal: UserGoalType;
  notes?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface DietRecommendation {
  insightTitle: string;
  summary: string;
  personalizationNote: string;
  suggestedCalorieDirection: string;
  proteinGuidance: string;
  carbGuidance: string;
  hydrationGuidance: string;
  mealSuggestions: string[];
  recoveryNote: string;
  nextBestAction: string;
  focusAreas: string[];
  safetyNote: string;
  signals: string[];
}

export type NutritionProfileSex = "male" | "female" | "prefer_not_to_say";
export type NutritionGoalType =
  | "lose_weight"
  | "maintain_weight"
  | "gain_muscle"
  | "general_wellness";
export type MealType = "breakfast" | "lunch" | "dinner" | "snack";
export type AnalysisConfidence = "high" | "medium" | "low";
export type FoodAnalysisInputType = "image" | "text";
export type SupplementFrequency = "daily" | "weekly" | "as_needed";
export type SupplementTime =
  | "morning"
  | "afternoon"
  | "evening"
  | "with_meal"
  | "before_bed";
export type ConditionType =
  | "pcos"
  | "diabetes"
  | "thyroid"
  | "hypertension"
  | "anemia"
  | "cholesterol"
  | "pregnancy"
  | "eating_disorder_history"
  | "other"
  | "prefer_not_to_say";

export interface UserNutritionProfile {
  userId: string;
  age?: number | null;
  sex?: NutritionProfileSex | null;
  heightCm: number;
  currentWeightKg: number;
  targetWeightKg?: number | null;
  goalType: NutritionGoalType;
  dailyCalorieTarget: number;
  dailyProteinTargetGrams: number;
  dailyCarbTargetGrams?: number | null;
  dailyFatTargetGrams?: number | null;
  targetTimeline?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface Supplement {
  id: string;
  userId: string;
  name: string;
  dosage?: string | null;
  frequency: SupplementFrequency;
  timeOfDay?: SupplementTime | null;
  notes?: string | null;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface HealthCondition {
  id: string;
  userId: string;
  conditionType: ConditionType;
  customName?: string | null;
  notes?: string | null;
  isActive: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface DetectedFoodItem {
  id: string;
  name: string;
  estimatedPortion: string;
  quantityGrams?: number | null;
  confidence: AnalysisConfidence;
  calories: number;
  proteinGrams: number;
  carbsGrams: number;
  fatGrams: number;
  userConfirmed: boolean;
}

export interface FoodImageAnalysis {
  id: string;
  userId: string;
  inputType: FoodAnalysisInputType;
  originalDescription?: string | null;
  imageLocalPath?: string | null;
  imageRemoteUrl?: string | null;
  detectedItems: DetectedFoodItem[];
  totalCalories: number;
  totalProteinGrams: number;
  totalCarbsGrams: number;
  totalFatGrams: number;
  confidence: AnalysisConfidence;
  notes: string[];
  createdAt?: string;
}

export interface MealLog {
  id: string;
  userId: string;
  date: string;
  mealType: MealType;
  loggedAt: string;
  source: "photo" | "text" | "library" | "manual";
  originalInput?: string | null;
  imageLocalPath?: string | null;
  items: DetectedFoodItem[];
  totalCalories: number;
  totalProteinGrams: number;
  totalCarbsGrams: number;
  totalFatGrams: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface WaterLog {
  id: string;
  userId: string;
  date: string;
  litres: number;
  createdAt?: string;
}

export interface DailyNutritionProgress {
  userId: string;
  date: string;
  calorieTarget: number;
  proteinTargetGrams: number;
  consumedCalories: number;
  consumedProteinGrams: number;
  consumedCarbsGrams: number;
  consumedFatGrams: number;
  remainingCalories: number;
  remainingProteinGrams: number;
}

export interface NutritionTargetSuggestion {
  calories: number;
  proteinGrams: number;
  carbsGrams: number | null;
  fatGrams: number | null;
  activityMultiplier: number;
}

export interface WeeklyNutritionSummaryDay {
  date: string;
  consumedCalories: number;
  consumedProteinGrams: number;
  mealCount: number;
}

export interface WeeklyNutritionSummary {
  userId: string;
  startDate: string;
  endDate: string;
  calorieTarget: number;
  proteinTargetGrams: number;
  averageCalories: number;
  averageProteinGrams: number;
  loggedDays: number;
  totalMeals: number;
  summaryLines: string[];
  dailyBreakdown: WeeklyNutritionSummaryDay[];
}
