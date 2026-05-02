import type {
  DailyNutritionProgress,
  DetectedFoodItem,
  FoodImageAnalysis,
  MealLog,
  NutritionGoalType,
  NutritionProfileSex,
  NutritionTargetSuggestion,
  UserNutritionProfile,
  WeeklyNutritionSummary
} from "../types/health.js";

type FoodReference = {
  name: string;
  defaultServingGrams: number;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
};

const foodLookup: Record<string, FoodReference> = {
  "chicken breast": { name: "Chicken breast", defaultServingGrams: 150, caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6 },
  rice: { name: "Rice", defaultServingGrams: 120, caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3 },
  egg: { name: "Egg", defaultServingGrams: 60, caloriesPer100g: 143, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 9.5 },
  oats: { name: "Oats", defaultServingGrams: 60, caloriesPer100g: 389, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9 },
  banana: { name: "Banana", defaultServingGrams: 100, caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 22.8, fatPer100g: 0.3 },
  avocado: { name: "Avocado", defaultServingGrams: 80, caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 8.5, fatPer100g: 14.7 },
  salmon: { name: "Salmon", defaultServingGrams: 140, caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13 },
  salad: { name: "Salad", defaultServingGrams: 80, caloriesPer100g: 20, proteinPer100g: 1.2, carbsPer100g: 3.6, fatPer100g: 0.2 },
  yogurt: { name: "Yogurt", defaultServingGrams: 150, caloriesPer100g: 63, proteinPer100g: 5.3, carbsPer100g: 7, fatPer100g: 1.6 },
  bread: { name: "Bread", defaultServingGrams: 60, caloriesPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3.2 },
  pasta: { name: "Pasta", defaultServingGrams: 140, caloriesPer100g: 157, proteinPer100g: 5.8, carbsPer100g: 30.9, fatPer100g: 0.9 },
  beef: { name: "Beef", defaultServingGrams: 150, caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15 },
  tofu: { name: "Tofu", defaultServingGrams: 140, caloriesPer100g: 144, proteinPer100g: 17.3, carbsPer100g: 2.8, fatPer100g: 8.7 },
  "protein shake": { name: "Protein shake", defaultServingGrams: 300, caloriesPer100g: 60, proteinPer100g: 10, carbsPer100g: 3, fatPer100g: 1.5 },
  coffee: { name: "Coffee", defaultServingGrams: 240, caloriesPer100g: 1, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0 },
  milk: { name: "Milk", defaultServingGrams: 240, caloriesPer100g: 50, proteinPer100g: 3.4, carbsPer100g: 5, fatPer100g: 1.9 }
};

export function minimumCaloriesForSex(sex?: NutritionProfileSex | null): number {
  switch (sex) {
    case "female":
      return 1200;
    case "male":
      return 1500;
    default:
      return 1300;
  }
}

export function estimateNutritionTargets(input: {
  age?: number | null;
  sex?: NutritionProfileSex | null;
  heightCm: number;
  currentWeightKg: number;
  goalType: NutritionGoalType;
  activityMultiplier?: number;
}): NutritionTargetSuggestion {
  const age = Math.max(input.age ?? 30, 18);
  const sexAdjustment =
    input.sex === "male" ? 5 :
    input.sex === "female" ? -161 :
    -78;

  const bmr = (10 * input.currentWeightKg) + (6.25 * input.heightCm) - (5 * age) + sexAdjustment;
  const activityMultiplier = input.activityMultiplier ?? 1.45;
  const tdee = Math.max(bmr * activityMultiplier, minimumCaloriesForSex(input.sex));

  const rawCalories =
    input.goalType === "lose_weight" ? tdee - 300 :
    input.goalType === "gain_muscle" ? tdee + 250 :
    tdee;

  const calories = Math.max(Math.round(rawCalories), minimumCaloriesForSex(input.sex));
  const proteinMultiplier =
    input.goalType === "lose_weight" ? 1.6 :
    input.goalType === "gain_muscle" ? 1.8 :
    1.4;

  const proteinGrams = Math.round(input.currentWeightKg * proteinMultiplier);
  const fatGrams = Math.round((calories * 0.28) / 9);
  const carbGrams = Math.max(0, Math.round((calories - (proteinGrams * 4) - (fatGrams * 9)) / 4));

  return {
    calories,
    proteinGrams,
    carbsGrams: carbGrams,
    fatGrams,
    activityMultiplier
  };
}

export function buildDetectedFoodItem(input: {
  id: string;
  name: string;
  estimatedPortion?: string;
  quantityGrams?: number | null;
  confidence?: "high" | "medium" | "low";
  userConfirmed?: boolean;
}): DetectedFoodItem {
  const reference = lookupFood(input.name);
  const quantityGrams = input.quantityGrams ?? reference?.defaultServingGrams ?? null;
  const totals = estimateItemTotals(reference, quantityGrams);

  return {
    id: input.id,
    name: reference?.name ?? input.name,
    estimatedPortion: input.estimatedPortion ?? (quantityGrams ? `${Math.round(quantityGrams)}g` : "1 serving"),
    quantityGrams,
    confidence: reference ? (input.confidence ?? "medium") : "low",
    calories: totals.calories,
    proteinGrams: totals.proteinGrams,
    carbsGrams: totals.carbsGrams,
    fatGrams: totals.fatGrams,
    userConfirmed: input.userConfirmed ?? false
  };
}

export function recalculateDetectedItems(items: DetectedFoodItem[]): DetectedFoodItem[] {
  return items.map((item) =>
    buildDetectedFoodItem({
      id: item.id,
      name: item.name,
      estimatedPortion: item.estimatedPortion,
      quantityGrams: item.quantityGrams,
      confidence: item.confidence,
      userConfirmed: item.userConfirmed
    })
  );
}

export function estimateMealTotals(items: DetectedFoodItem[]) {
  return {
    totalCalories: items.reduce((sum, item) => sum + item.calories, 0),
    totalProteinGrams: roundOneDecimal(items.reduce((sum, item) => sum + item.proteinGrams, 0)),
    totalCarbsGrams: roundOneDecimal(items.reduce((sum, item) => sum + item.carbsGrams, 0)),
    totalFatGrams: roundOneDecimal(items.reduce((sum, item) => sum + item.fatGrams, 0))
  };
}

export function buildMockAnalysis(params: {
  userId: string;
  imageLocalPath?: string | null;
  imageRemoteUrl?: string | null;
  imageWidth?: number;
  imageHeight?: number;
}): FoodImageAnalysis {
  const shape = classifyShape(params.imageWidth, params.imageHeight);
  const items =
    shape === "landscape" ? [
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "chicken breast", estimatedPortion: "150g", quantityGrams: 150, confidence: "high" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "rice", estimatedPortion: "120g", quantityGrams: 120, confidence: "medium" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "salad", estimatedPortion: "80g", quantityGrams: 80, confidence: "medium" })
    ] :
    shape === "square" ? [
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "salmon", estimatedPortion: "140g", quantityGrams: 140, confidence: "medium" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "avocado", estimatedPortion: "80g", quantityGrams: 80, confidence: "medium" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "bread", estimatedPortion: "60g", quantityGrams: 60, confidence: "low" })
    ] : [
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "oats", estimatedPortion: "60g", quantityGrams: 60, confidence: "high" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "banana", estimatedPortion: "100g", quantityGrams: 100, confidence: "medium" }),
      buildDetectedFoodItem({ id: crypto.randomUUID(), name: "yogurt", estimatedPortion: "150g", quantityGrams: 150, confidence: "medium" })
    ];

  const totals = estimateMealTotals(items);
  return {
    id: crypto.randomUUID(),
    userId: params.userId,
    inputType: "image",
    originalDescription: null,
    imageLocalPath: params.imageLocalPath ?? null,
    imageRemoteUrl: params.imageRemoteUrl ?? null,
    detectedItems: items,
    confidence: items.some((item) => item.confidence === "low") ? "medium" : "high",
    notes: [
      "Nutrition values are estimates based on visible food items.",
      "Please confirm items and portions before logging."
    ],
    createdAt: new Date().toISOString(),
    ...totals
  };
}

export function buildDailyNutritionProgress(
  userId: string,
  date: string,
  profile: UserNutritionProfile,
  mealLogs: MealLog[]
): DailyNutritionProgress {
  const consumedCalories = mealLogs.reduce((sum, meal) => sum + meal.totalCalories, 0);
  const consumedProteinGrams = roundOneDecimal(mealLogs.reduce((sum, meal) => sum + meal.totalProteinGrams, 0));
  const consumedCarbsGrams = roundOneDecimal(mealLogs.reduce((sum, meal) => sum + meal.totalCarbsGrams, 0));
  const consumedFatGrams = roundOneDecimal(mealLogs.reduce((sum, meal) => sum + meal.totalFatGrams, 0));

  return {
    userId,
    date,
    calorieTarget: profile.dailyCalorieTarget,
    proteinTargetGrams: profile.dailyProteinTargetGrams,
    consumedCalories,
    consumedProteinGrams,
    consumedCarbsGrams,
    consumedFatGrams,
    remainingCalories: profile.dailyCalorieTarget - consumedCalories,
    remainingProteinGrams: roundOneDecimal(profile.dailyProteinTargetGrams - consumedProteinGrams)
  };
}

export function buildWeeklyNutritionSummary(
  userId: string,
  mealLogs: MealLog[],
  profile: UserNutritionProfile
): WeeklyNutritionSummary {
  const grouped = new Map<string, MealLog[]>();
  for (const meal of mealLogs) {
    grouped.set(meal.date, [...(grouped.get(meal.date) ?? []), meal]);
  }

  const dates = [...grouped.keys()].sort();
  const dailyBreakdown = dates.map((date) => {
    const meals = grouped.get(date) ?? [];
    return {
      date,
      consumedCalories: meals.reduce((sum, meal) => sum + meal.totalCalories, 0),
      consumedProteinGrams: roundOneDecimal(meals.reduce((sum, meal) => sum + meal.totalProteinGrams, 0)),
      mealCount: meals.length
    };
  });

  const loggedDays = dailyBreakdown.length;
  const totalMeals = mealLogs.length;
  const averageCalories = loggedDays > 0
    ? Math.round(dailyBreakdown.reduce((sum, day) => sum + day.consumedCalories, 0) / loggedDays)
    : 0;
  const averageProteinGrams = loggedDays > 0
    ? roundOneDecimal(dailyBreakdown.reduce((sum, day) => sum + day.consumedProteinGrams, 0) / loggedDays)
    : 0;

  const summaryLines: string[] = [];
  if (loggedDays === 0) {
    summaryLines.push("Log one meal a day to start building your weekly nutrition picture.");
  } else {
    summaryLines.push(`You logged meals on ${loggedDays} day${loggedDays === 1 ? "" : "s"} this week.`);
    summaryLines.push(`Average intake was ${averageCalories} estimated calories and ${Math.round(averageProteinGrams)}g protein on logged days.`);
    if (averageProteinGrams >= profile.dailyProteinTargetGrams * 0.85) {
      summaryLines.push("Protein intake stayed close to your target on average.");
    } else {
      summaryLines.push("Protein averaged below target, so one extra protein-forward meal could help next week.");
    }
  }

  return {
    userId,
    startDate: dates[0] ?? "",
    endDate: dates[dates.length - 1] ?? "",
    calorieTarget: profile.dailyCalorieTarget,
    proteinTargetGrams: profile.dailyProteinTargetGrams,
    averageCalories,
    averageProteinGrams,
    loggedDays,
    totalMeals,
    summaryLines,
    dailyBreakdown
  };
}

function lookupFood(name: string): FoodReference | undefined {
  const normalized = name.toLowerCase().trim();
  return foodLookup[normalized] ?? Object.entries(foodLookup).find(([key]) => normalized.includes(key))?.[1];
}

function estimateItemTotals(reference: FoodReference | undefined, quantityGrams?: number | null) {
  if (!reference) {
    return {
      calories: 120,
      proteinGrams: 6,
      carbsGrams: 12,
      fatGrams: 4
    };
  }

  const grams = quantityGrams ?? reference.defaultServingGrams;
  const multiplier = grams / 100;
  return {
    calories: Math.round(reference.caloriesPer100g * multiplier),
    proteinGrams: roundOneDecimal(reference.proteinPer100g * multiplier),
    carbsGrams: roundOneDecimal(reference.carbsPer100g * multiplier),
    fatGrams: roundOneDecimal(reference.fatPer100g * multiplier)
  };
}

function classifyShape(width?: number, height?: number): "landscape" | "portrait" | "square" {
  if (!width || !height) {
    return "landscape";
  }
  if (Math.abs(width - height) < 40) {
    return "square";
  }
  return width > height ? "landscape" : "portrait";
}

function roundOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}
