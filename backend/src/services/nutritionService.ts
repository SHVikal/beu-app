import { currentIsoDay, shiftIsoDay } from "../utils/date.js";
import { NutritionRepository } from "../repositories/nutritionRepository.js";
import {
  buildDailyNutritionProgress,
  buildWeeklyNutritionSummary,
  estimateNutritionTargets,
  estimateMealTotals,
  minimumCaloriesForSex
} from "./nutritionSupport.js";
import type {
  DailyNutritionProgress,
  HealthCondition,
  MealLog,
  Supplement,
  UserNutritionProfile,
  WeeklyNutritionSummary
} from "../types/health.js";

export class NutritionService {
  constructor(private readonly repository = new NutritionRepository()) {}

  saveProfile(profile: UserNutritionProfile): UserNutritionProfile {
    const minimumCalories = minimumCaloriesForSex(profile.sex);
    if (profile.dailyCalorieTarget < minimumCalories) {
      throw new Error(`Daily calorie target must be at least ${minimumCalories} for this profile.`);
    }
    return this.repository.saveProfile(profile);
  }

  getProfile(userId: string): UserNutritionProfile | null {
    return this.repository.getProfile(userId);
  }

  estimateTargets(input: {
    age?: number | null;
    sex?: UserNutritionProfile["sex"];
    heightCm: number;
    currentWeightKg: number;
    goalType: UserNutritionProfile["goalType"];
  }) {
    return estimateNutritionTargets(input);
  }

  saveMealLog(mealLog: MealLog): MealLog {
    return this.repository.saveMealLog(this.normalizedMealLog({
      ...mealLog,
      id: mealLog.id || crypto.randomUUID()
    }));
  }

  updateMealLog(mealLogId: string, mealLog: MealLog): MealLog {
    return this.repository.saveMealLog(this.normalizedMealLog({
      ...mealLog,
      id: mealLogId
    }));
  }

  getMealLogsByDate(userId: string, date: string): MealLog[] {
    return this.repository.listMealLogsByDate(userId, date);
  }

  deleteMealLog(mealLogId: string): boolean {
    return this.repository.deleteMealLog(mealLogId);
  }

  private normalizedMealLog(mealLog: MealLog): MealLog {
    const sanitizedItems = mealLog.items
      .map((item) => ({
        ...item,
        name: item.name.trim(),
        estimatedPortion: item.estimatedPortion.trim() || "1 serving",
        calories: Math.max(0, Math.round(item.calories)),
        proteinGrams: Math.max(0, item.proteinGrams),
        carbsGrams: Math.max(0, item.carbsGrams),
        fatGrams: Math.max(0, item.fatGrams)
      }))
      .filter((item) => item.name.length > 0);

    if (sanitizedItems.length === 0) {
      throw new Error("Meal must contain at least one item.");
    }

    const totals = estimateMealTotals(sanitizedItems);
    return {
      ...mealLog,
      items: sanitizedItems,
      totalCalories: totals.totalCalories,
      totalProteinGrams: totals.totalProteinGrams,
      totalCarbsGrams: totals.totalCarbsGrams,
      totalFatGrams: totals.totalFatGrams
    };
  }

  saveSupplement(supplement: Supplement): Supplement {
    return this.repository.saveSupplement({
      ...supplement,
      id: supplement.id || crypto.randomUUID()
    });
  }

  listSupplements(userId: string): Supplement[] {
    return this.repository.listSupplements(userId);
  }

  deleteSupplement(id: string): boolean {
    return this.repository.deleteSupplement(id);
  }

  saveHealthCondition(condition: HealthCondition): HealthCondition {
    return this.repository.saveHealthCondition({
      ...condition,
      id: condition.id || crypto.randomUUID()
    });
  }

  listHealthConditions(userId: string): HealthCondition[] {
    return this.repository.listHealthConditions(userId);
  }

  deleteHealthCondition(id: string): boolean {
    return this.repository.deleteHealthCondition(id);
  }

  getDailyProgress(userId: string, date: string): DailyNutritionProgress {
    const profile = this.repository.getProfile(userId);
    if (!profile) {
      throw new Error("Nutrition profile not found.");
    }
    const meals = this.repository.listMealLogsByDate(userId, date);
    return buildDailyNutritionProgress(userId, date, profile, meals);
  }

  getWeeklySummary(userId: string): WeeklyNutritionSummary {
    const profile = this.repository.getProfile(userId);
    if (!profile) {
      throw new Error("Nutrition profile not found.");
    }
    const endDate = currentIsoDay();
    const startDate = shiftIsoDay(endDate, -6);
    const meals = this.repository.listMealLogsByRange(userId, startDate, endDate);
    return buildWeeklyNutritionSummary(userId, meals, profile);
  }
}
