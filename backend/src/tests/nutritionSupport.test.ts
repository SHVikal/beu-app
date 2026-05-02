import test from "node:test";
import assert from "node:assert/strict";
import {
  buildDailyNutritionProgress,
  buildDetectedFoodItem,
  buildWeeklyNutritionSummary,
  estimateMealTotals,
  estimateNutritionTargets,
  minimumCaloriesForSex,
  recalculateDetectedItems
} from "../services/nutritionSupport.js";
import type { MealLog, UserNutritionProfile } from "../types/health.js";

test("nutrition target calculation respects minimum calories", () => {
  const suggestion = estimateNutritionTargets({
    age: 29,
    sex: "female",
    heightCm: 162,
    currentWeightKg: 53,
    goalType: "lose_weight",
    activityMultiplier: 1.2
  });

  assert.equal(minimumCaloriesForSex("female"), 1200);
  assert.ok(suggestion.calories >= 1200);
});

test("nutrition target calculation increases calories for muscle gain", () => {
  const maintain = estimateNutritionTargets({
    age: 31,
    sex: "male",
    heightCm: 180,
    currentWeightKg: 80,
    goalType: "maintain_weight",
    activityMultiplier: 1.45
  });
  const gain = estimateNutritionTargets({
    age: 31,
    sex: "male",
    heightCm: 180,
    currentWeightKg: 80,
    goalType: "gain_muscle",
    activityMultiplier: 1.45
  });

  assert.ok(gain.calories > maintain.calories);
  assert.ok(gain.proteinGrams >= maintain.proteinGrams);
});

test("macro calculation per food item uses grams", () => {
  const item = buildDetectedFoodItem({
    id: "1",
    name: "chicken breast",
    quantityGrams: 150
  });

  assert.equal(item.calories, 248);
  assert.equal(item.proteinGrams, 46.5);
  assert.equal(item.carbsGrams, 0);
});

test("meal total calculation sums all detected items", () => {
  const items = [
    buildDetectedFoodItem({ id: "1", name: "rice", quantityGrams: 120 }),
    buildDetectedFoodItem({ id: "2", name: "salad", quantityGrams: 80 })
  ];

  const totals = estimateMealTotals(items);
  assert.equal(totals.totalCalories, 172);
  assert.equal(totals.totalProteinGrams, 4.2);
  assert.equal(totals.totalCarbsGrams, 36.5);
});

test("editing detected item recalculates totals", () => {
  const items = recalculateDetectedItems([
    buildDetectedFoodItem({ id: "1", name: "banana", quantityGrams: 200 }),
    buildDetectedFoodItem({ id: "2", name: "yogurt", quantityGrams: 150 })
  ]);

  const totals = estimateMealTotals(items);
  assert.equal(totals.totalCalories, 273);
  assert.equal(totals.totalProteinGrams, 10.2);
});

test("daily nutrition progress calculation returns remaining values", () => {
  const profile: UserNutritionProfile = {
    userId: "demo-user",
    age: 30,
    sex: "male",
    heightCm: 180,
    currentWeightKg: 80,
    targetWeightKg: 76,
    goalType: "maintain_weight",
    dailyCalorieTarget: 2200,
    dailyProteinTargetGrams: 140,
    dailyCarbTargetGrams: 240,
    dailyFatTargetGrams: 70,
    targetTimeline: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  const mealLogs: MealLog[] = [
    {
      id: "1",
      userId: "demo-user",
      date: "2026-04-26",
      mealType: "breakfast",
      loggedAt: new Date().toISOString(),
      source: "manual",
      originalInput: null,
      imageLocalPath: null,
      items: [buildDetectedFoodItem({ id: "i1", name: "oats", quantityGrams: 60 })],
      totalCalories: 233,
      totalProteinGrams: 10.1,
      totalCarbsGrams: 39.8,
      totalFatGrams: 4.1,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    },
    {
      id: "2",
      userId: "demo-user",
      date: "2026-04-26",
      mealType: "lunch",
      loggedAt: new Date().toISOString(),
      source: "manual",
      originalInput: null,
      imageLocalPath: null,
      items: [buildDetectedFoodItem({ id: "i2", name: "chicken breast", quantityGrams: 150 })],
      totalCalories: 248,
      totalProteinGrams: 46.5,
      totalCarbsGrams: 0,
      totalFatGrams: 5.4,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
  ];

  const progress = buildDailyNutritionProgress("demo-user", "2026-04-26", profile, mealLogs);
  assert.equal(progress.consumedCalories, 481);
  assert.equal(progress.remainingCalories, 1719);
  assert.equal(progress.remainingProteinGrams, 83.4);
});

test("weekly nutrition summary handles logged days and averages", () => {
  const profile: UserNutritionProfile = {
    userId: "demo-user",
    age: 30,
    sex: "female",
    heightCm: 165,
    currentWeightKg: 60,
    targetWeightKg: null,
    goalType: "general_wellness",
    dailyCalorieTarget: 1900,
    dailyProteinTargetGrams: 90,
    dailyCarbTargetGrams: 220,
    dailyFatTargetGrams: 60,
    targetTimeline: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  const meals: MealLog[] = [
    {
      id: "1",
      userId: "demo-user",
      date: "2026-04-20",
      mealType: "breakfast",
      loggedAt: new Date().toISOString(),
      source: "manual",
      originalInput: null,
      imageLocalPath: null,
      items: [],
      totalCalories: 400,
      totalProteinGrams: 22,
      totalCarbsGrams: 40,
      totalFatGrams: 12,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    },
    {
      id: "2",
      userId: "demo-user",
      date: "2026-04-21",
      mealType: "dinner",
      loggedAt: new Date().toISOString(),
      source: "manual",
      originalInput: null,
      imageLocalPath: null,
      items: [],
      totalCalories: 700,
      totalProteinGrams: 35,
      totalCarbsGrams: 50,
      totalFatGrams: 20,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
  ];

  const summary = buildWeeklyNutritionSummary("demo-user", meals, profile);
  assert.equal(summary.loggedDays, 2);
  assert.equal(summary.totalMeals, 2);
  assert.equal(summary.averageCalories, 550);
  assert.equal(summary.dailyBreakdown.length, 2);
});
