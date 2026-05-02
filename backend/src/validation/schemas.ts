import { z } from "zod";
import { isIsoDay } from "../utils/date.js";

const isoDay = z
  .string()
  .refine((value) => isIsoDay(value), "Expected date in YYYY-MM-DD format.");

const optionalPositiveMetric = z
  .number()
  .nonnegative()
  .nullable()
  .optional()
  .transform((value) => {
    if (value === undefined || value === null || value <= 0) {
      return null;
    }
    return value;
  });

export const healthSummarySchema = z.object({
  userId: z.string().min(1),
  date: isoDay,
  steps: z.number().int().nonnegative().default(0),
  activeEnergyKcal: z.number().nonnegative().default(0),
  basalEnergyKcal: optionalPositiveMetric,
  workoutCount: z.number().int().nonnegative().default(0),
  workoutMinutes: z.number().nonnegative().default(0),
  workoutEnergyKcal: z.number().nonnegative().default(0),
  totalEnergyBurnedKcal: optionalPositiveMetric,
  estimatedTotalBurnKcal: z.number().nonnegative().default(0),
  sleepHours: z.number().nonnegative().default(0),
  restingHeartRateBpm: optionalPositiveMetric,
  hrvMs: optionalPositiveMetric,
  weightKg: optionalPositiveMetric,
  heightCm: optionalPositiveMetric
});

export const userGoalSchema = z.object({
  userId: z.string().min(1),
  goal: z.enum(["fat_loss", "muscle_gain", "maintenance", "general_wellness"]),
  notes: z.string().max(500).optional().nullable()
});

export const recommendationRequestSchema = z.object({
  userId: z.string().min(1),
  date: isoDay.optional()
});

export const rangeQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(30).default(7)
});

const confidenceSchema = z.enum(["high", "medium", "low"]);
const mealTypeSchema = z.enum(["breakfast", "lunch", "dinner", "snack"]);
const textMealTypeSchema = z.enum(["breakfast", "lunch", "dinner", "snack", "unknown"]);
const nutritionGoalSchema = z.enum(["lose_weight", "maintain_weight", "gain_muscle", "general_wellness"]);
const sexSchema = z.enum(["male", "female", "prefer_not_to_say"]);
const supplementFrequencySchema = z.enum(["daily", "weekly", "as_needed"]);
const supplementTimeSchema = z.enum(["morning", "afternoon", "evening", "with_meal", "before_bed"]);
const conditionTypeSchema = z.enum([
  "pcos",
  "diabetes",
  "thyroid",
  "hypertension",
  "anemia",
  "cholesterol",
  "pregnancy",
  "eating_disorder_history",
  "other",
  "prefer_not_to_say"
]);

export const nutritionProfileSchema = z.object({
  userId: z.string().min(1),
  age: z.number().int().min(13).max(120).optional().nullable(),
  sex: sexSchema.optional().nullable(),
  heightCm: z.number().positive(),
  currentWeightKg: z.number().positive(),
  targetWeightKg: z.number().positive().optional().nullable(),
  goalType: nutritionGoalSchema,
  dailyCalorieTarget: z.number().int().positive(),
  dailyProteinTargetGrams: z.number().int().positive(),
  dailyCarbTargetGrams: z.number().int().positive().optional().nullable(),
  dailyFatTargetGrams: z.number().int().positive().optional().nullable(),
  targetTimeline: z.string().max(100).optional().nullable()
});

export const detectedFoodItemSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  estimatedPortion: z.string().min(1),
  quantityGrams: z.number().positive().optional().nullable(),
  confidence: confidenceSchema,
  calories: z.number().int().nonnegative(),
  proteinGrams: z.number().nonnegative(),
  carbsGrams: z.number().nonnegative(),
  fatGrams: z.number().nonnegative(),
  userConfirmed: z.boolean()
});

export const foodImageAnalysisSchema = z.object({
  userId: z.string().min(1),
  imageLocalPath: z.string().optional().nullable(),
  imageRemoteUrl: z.string().url().optional().nullable(),
  imageWidth: z.number().positive().optional(),
  imageHeight: z.number().positive().optional()
});

export const analysisItemsUpdateSchema = z.object({
  userId: z.string().min(1),
  imageLocalPath: z.string().optional().nullable(),
  items: z.array(detectedFoodItemSchema).min(1)
});

export const foodTextAnalysisRequestSchema = z.object({
  userId: z.string().min(1),
  description: z.string().trim().min(5).max(2000),
  mealType: textMealTypeSchema.default("unknown"),
  dietPreference: z.enum(["indian_vegetarian", "vegetarian", "vegan", "no_preference"]).default("no_preference")
});

export const mealLogSchema = z.object({
  id: z.string().min(1).optional(),
  userId: z.string().min(1),
  date: isoDay,
  mealType: mealTypeSchema,
  loggedAt: z.string().datetime().optional(),
  source: z.enum(["photo", "text", "library", "manual"]).default("manual"),
  originalInput: z.string().trim().max(2000).optional().nullable(),
  imageLocalPath: z.string().optional().nullable(),
  items: z.array(detectedFoodItemSchema).min(1),
  totalCalories: z.number().int().nonnegative(),
  totalProteinGrams: z.number().nonnegative(),
  totalCarbsGrams: z.number().nonnegative(),
  totalFatGrams: z.number().nonnegative()
});

export const supplementSchema = z.object({
  id: z.string().min(1).optional(),
  userId: z.string().min(1),
  name: z.string().trim().min(1).max(80),
  dosage: z.string().trim().max(80).optional().nullable(),
  frequency: supplementFrequencySchema,
  timeOfDay: supplementTimeSchema.optional().nullable(),
  notes: z.string().trim().max(500).optional().nullable(),
  isActive: z.boolean().default(true),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional()
});

export const healthConditionSchema = z.object({
  id: z.string().min(1).optional(),
  userId: z.string().min(1),
  conditionType: conditionTypeSchema,
  customName: z.string().trim().max(80).optional().nullable(),
  notes: z.string().trim().max(500).optional().nullable(),
  isActive: z.boolean().default(true),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional()
});

export const waterLogSchema = z.object({
  userId: z.string().min(1),
  litres: z.number().positive().max(5),
  date: isoDay.optional()
});

export const planMealLogSchema = z.object({
  userId: z.string().min(1),
  source: z.enum(["photo", "text"]),
  text: z.string().trim().max(2000).optional().nullable(),
  image: z.string().optional().nullable(),
  mealSlot: mealTypeSchema,
  items: z.array(detectedFoodItemSchema).min(1),
  date: isoDay.optional()
});
