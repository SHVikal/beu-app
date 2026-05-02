import { db } from "../db/database.js";
import type {
  DetectedFoodItem,
  FoodImageAnalysis,
  HealthCondition,
  MealLog,
  Supplement,
  UserNutritionProfile,
  WaterLog
} from "../types/health.js";

type NutritionProfileRow = {
  user_id: string;
  age: number | null;
  sex: UserNutritionProfile["sex"];
  height_cm: number;
  current_weight_kg: number;
  target_weight_kg: number | null;
  goal_type: UserNutritionProfile["goalType"];
  daily_calorie_target: number;
  daily_protein_target_grams: number;
  daily_carb_target_grams: number | null;
  daily_fat_target_grams: number | null;
  target_timeline: string | null;
  created_at: string;
  updated_at: string;
};

type AnalysisRow = {
  id: string;
  user_id: string;
  input_type: FoodImageAnalysis["inputType"];
  original_description: string | null;
  image_local_path: string | null;
  image_remote_url: string | null;
  detected_items_json: string;
  total_calories: number;
  total_protein_grams: number;
  total_carbs_grams: number;
  total_fat_grams: number;
  confidence: FoodImageAnalysis["confidence"];
  notes_json: string;
  created_at: string;
};

type MealLogRow = {
  id: string;
  user_id: string;
  date: string;
  meal_type: MealLog["mealType"];
  logged_at: string;
  source: MealLog["source"];
  original_input: string | null;
  image_local_path: string | null;
  items_json: string;
  total_calories: number;
  total_protein_grams: number;
  total_carbs_grams: number;
  total_fat_grams: number;
  created_at: string;
  updated_at: string;
};

type SupplementRow = {
  id: string;
  user_id: string;
  name: string;
  dosage: string | null;
  frequency: Supplement["frequency"];
  time_of_day: Supplement["timeOfDay"];
  notes: string | null;
  is_active: number;
  created_at: string;
  updated_at: string;
};

type WaterLogRow = {
  id: string;
  user_id: string;
  date: string;
  litres: number;
  created_at: string;
};

type HealthConditionRow = {
  id: string;
  user_id: string;
  condition_type: HealthCondition["conditionType"];
  custom_name: string | null;
  notes: string | null;
  is_active: number;
  created_at: string;
  updated_at: string;
};

export class NutritionRepository {
  saveProfile(profile: UserNutritionProfile): UserNutritionProfile {
    db.prepare(`
      INSERT INTO user_nutrition_profiles (
        user_id, age, sex, height_cm, current_weight_kg, target_weight_kg,
        goal_type, daily_calorie_target, daily_protein_target_grams,
        daily_carb_target_grams, daily_fat_target_grams, target_timeline, updated_at
      ) VALUES (
        @userId, @age, @sex, @heightCm, @currentWeightKg, @targetWeightKg,
        @goalType, @dailyCalorieTarget, @dailyProteinTargetGrams,
        @dailyCarbTargetGrams, @dailyFatTargetGrams, @targetTimeline, CURRENT_TIMESTAMP
      )
      ON CONFLICT(user_id) DO UPDATE SET
        age = excluded.age,
        sex = excluded.sex,
        height_cm = excluded.height_cm,
        current_weight_kg = excluded.current_weight_kg,
        target_weight_kg = excluded.target_weight_kg,
        goal_type = excluded.goal_type,
        daily_calorie_target = excluded.daily_calorie_target,
        daily_protein_target_grams = excluded.daily_protein_target_grams,
        daily_carb_target_grams = excluded.daily_carb_target_grams,
        daily_fat_target_grams = excluded.daily_fat_target_grams,
        target_timeline = excluded.target_timeline,
        updated_at = CURRENT_TIMESTAMP
    `).run({
      ...profile,
      age: profile.age ?? null,
      sex: profile.sex ?? null,
      targetWeightKg: profile.targetWeightKg ?? null,
      dailyCarbTargetGrams: profile.dailyCarbTargetGrams ?? null,
      dailyFatTargetGrams: profile.dailyFatTargetGrams ?? null,
      targetTimeline: profile.targetTimeline ?? null
    });

    const stored = this.getProfile(profile.userId);
    if (!stored) {
      throw new Error("Failed to persist nutrition profile.");
    }
    return stored;
  }

  getProfile(userId: string): UserNutritionProfile | null {
    const row = db.prepare(`SELECT * FROM user_nutrition_profiles WHERE user_id = ?`).get(userId) as NutritionProfileRow | undefined;
    return row ? profileFromRow(row) : null;
  }

  saveAnalysis(analysis: FoodImageAnalysis): FoodImageAnalysis {
    db.prepare(`
      INSERT OR REPLACE INTO food_image_analyses (
        id, user_id, input_type, original_description, image_local_path, image_remote_url, detected_items_json,
        total_calories, total_protein_grams, total_carbs_grams, total_fat_grams,
        confidence, notes_json, created_at
      ) VALUES (
        @id, @userId, @inputType, @originalDescription, @imageLocalPath, @imageRemoteUrl, @detectedItemsJson,
        @totalCalories, @totalProteinGrams, @totalCarbsGrams, @totalFatGrams,
        @confidence, @notesJson, COALESCE(@createdAt, CURRENT_TIMESTAMP)
      )
    `).run({
      ...analysis,
      originalDescription: analysis.originalDescription ?? null,
      imageLocalPath: analysis.imageLocalPath ?? null,
      imageRemoteUrl: analysis.imageRemoteUrl ?? null,
      detectedItemsJson: JSON.stringify(analysis.detectedItems),
      notesJson: JSON.stringify(analysis.notes ?? [])
    });

    const stored = this.getAnalysis(analysis.id);
    if (!stored) {
      throw new Error("Failed to persist food analysis.");
    }
    return stored;
  }

  getAnalysis(id: string): FoodImageAnalysis | null {
    const row = db.prepare(`SELECT * FROM food_image_analyses WHERE id = ?`).get(id) as AnalysisRow | undefined;
    return row ? analysisFromRow(row) : null;
  }

  saveMealLog(mealLog: MealLog): MealLog {
    db.prepare(`
      INSERT OR REPLACE INTO meal_logs (
        id, user_id, date, meal_type, logged_at, source, original_input, image_local_path, items_json,
        total_calories, total_protein_grams, total_carbs_grams, total_fat_grams,
        created_at, updated_at
      ) VALUES (
        @id, @userId, @date, @mealType, COALESCE(@loggedAt, CURRENT_TIMESTAMP), @source, @originalInput, @imageLocalPath, @itemsJson,
        @totalCalories, @totalProteinGrams, @totalCarbsGrams, @totalFatGrams,
        COALESCE(@createdAt, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP
      )
    `).run({
      ...mealLog,
      loggedAt: mealLog.loggedAt ?? null,
      source: mealLog.source ?? "manual",
      originalInput: mealLog.originalInput ?? null,
      imageLocalPath: mealLog.imageLocalPath ?? null,
      itemsJson: JSON.stringify(mealLog.items)
    });

    const stored = this.getMealLog(mealLog.id);
    if (!stored) {
      throw new Error("Failed to persist meal log.");
    }
    return stored;
  }

  getMealLog(id: string): MealLog | null {
    const row = db.prepare(`SELECT * FROM meal_logs WHERE id = ?`).get(id) as MealLogRow | undefined;
    return row ? mealLogFromRow(row) : null;
  }

  listMealLogsByDate(userId: string, date: string): MealLog[] {
    const rows = db.prepare(`SELECT * FROM meal_logs WHERE user_id = ? AND date = ? ORDER BY created_at ASC`).all(userId, date) as MealLogRow[];
    return rows.map(mealLogFromRow);
  }

  listMealLogsByRange(userId: string, startDate: string, endDate: string): MealLog[] {
    const rows = db.prepare(`
      SELECT * FROM meal_logs
      WHERE user_id = ? AND date >= ? AND date <= ?
      ORDER BY date ASC, created_at ASC
    `).all(userId, startDate, endDate) as MealLogRow[];
    return rows.map(mealLogFromRow);
  }

  deleteMealLog(id: string): boolean {
    const result = db.prepare(`DELETE FROM meal_logs WHERE id = ?`).run(id);
    return result.changes > 0;
  }

  saveWaterLog(waterLog: WaterLog): WaterLog {
    db.prepare(`
      INSERT OR REPLACE INTO water_logs (
        id, user_id, date, litres, created_at
      ) VALUES (
        @id, @userId, @date, @litres, COALESCE(@createdAt, CURRENT_TIMESTAMP)
      )
    `).run({
      ...waterLog
    });

    const stored = this.getWaterLog(waterLog.id);
    if (!stored) {
      throw new Error("Failed to persist water log.");
    }
    return stored;
  }

  getWaterLog(id: string): WaterLog | null {
    const row = db.prepare(`SELECT * FROM water_logs WHERE id = ?`).get(id) as WaterLogRow | undefined;
    return row ? waterLogFromRow(row) : null;
  }

  listWaterLogsByDate(userId: string, date: string): WaterLog[] {
    const rows = db.prepare(`
      SELECT * FROM water_logs WHERE user_id = ? AND date = ? ORDER BY created_at ASC
    `).all(userId, date) as WaterLogRow[];
    return rows.map(waterLogFromRow);
  }

  listWaterLogsByRange(userId: string, startDate: string, endDate: string): WaterLog[] {
    const rows = db.prepare(`
      SELECT * FROM water_logs
      WHERE user_id = ? AND date >= ? AND date <= ?
      ORDER BY date ASC, created_at ASC
    `).all(userId, startDate, endDate) as WaterLogRow[];
    return rows.map(waterLogFromRow);
  }

  saveSupplement(supplement: Supplement): Supplement {
    db.prepare(`
      INSERT OR REPLACE INTO supplements (
        id, user_id, name, dosage, frequency, time_of_day, notes, is_active, created_at, updated_at
      ) VALUES (
        @id, @userId, @name, @dosage, @frequency, @timeOfDay, @notes, @isActive, COALESCE(@createdAt, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP
      )
    `).run({
      ...supplement,
      dosage: supplement.dosage ?? null,
      timeOfDay: supplement.timeOfDay ?? null,
      notes: supplement.notes ?? null,
      isActive: supplement.isActive ? 1 : 0
    });

    const stored = this.getSupplement(supplement.id);
    if (!stored) {
      throw new Error("Failed to persist supplement.");
    }
    return stored;
  }

  listSupplements(userId: string): Supplement[] {
    const rows = db.prepare(`
      SELECT * FROM supplements WHERE user_id = ? ORDER BY is_active DESC, updated_at DESC, created_at DESC
    `).all(userId) as SupplementRow[];
    return rows.map(supplementFromRow);
  }

  getSupplement(id: string): Supplement | null {
    const row = db.prepare(`SELECT * FROM supplements WHERE id = ?`).get(id) as SupplementRow | undefined;
    return row ? supplementFromRow(row) : null;
  }

  deleteSupplement(id: string): boolean {
    const result = db.prepare(`DELETE FROM supplements WHERE id = ?`).run(id);
    return result.changes > 0;
  }

  saveHealthCondition(condition: HealthCondition): HealthCondition {
    db.prepare(`
      INSERT OR REPLACE INTO health_conditions (
        id, user_id, condition_type, custom_name, notes, is_active, created_at, updated_at
      ) VALUES (
        @id, @userId, @conditionType, @customName, @notes, @isActive, COALESCE(@createdAt, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP
      )
    `).run({
      ...condition,
      customName: condition.customName ?? null,
      notes: condition.notes ?? null,
      isActive: condition.isActive ? 1 : 0
    });

    const stored = this.getHealthCondition(condition.id);
    if (!stored) {
      throw new Error("Failed to persist health condition.");
    }
    return stored;
  }

  listHealthConditions(userId: string): HealthCondition[] {
    const rows = db.prepare(`
      SELECT * FROM health_conditions WHERE user_id = ? ORDER BY is_active DESC, updated_at DESC, created_at DESC
    `).all(userId) as HealthConditionRow[];
    return rows.map(healthConditionFromRow);
  }

  getHealthCondition(id: string): HealthCondition | null {
    const row = db.prepare(`SELECT * FROM health_conditions WHERE id = ?`).get(id) as HealthConditionRow | undefined;
    return row ? healthConditionFromRow(row) : null;
  }

  deleteHealthCondition(id: string): boolean {
    const result = db.prepare(`DELETE FROM health_conditions WHERE id = ?`).run(id);
    return result.changes > 0;
  }
}

function profileFromRow(row: NutritionProfileRow): UserNutritionProfile {
  return {
    userId: row.user_id,
    age: row.age,
    sex: row.sex,
    heightCm: row.height_cm,
    currentWeightKg: row.current_weight_kg,
    targetWeightKg: row.target_weight_kg,
    goalType: row.goal_type,
    dailyCalorieTarget: row.daily_calorie_target,
    dailyProteinTargetGrams: row.daily_protein_target_grams,
    dailyCarbTargetGrams: row.daily_carb_target_grams,
    dailyFatTargetGrams: row.daily_fat_target_grams,
    targetTimeline: row.target_timeline,
    createdAt: normalizeTimestamp(row.created_at),
    updatedAt: normalizeTimestamp(row.updated_at)
  };
}

function analysisFromRow(row: AnalysisRow): FoodImageAnalysis {
  return {
    id: row.id,
    userId: row.user_id,
    inputType: row.input_type ?? "image",
    originalDescription: row.original_description,
    imageLocalPath: row.image_local_path,
    imageRemoteUrl: row.image_remote_url,
    detectedItems: JSON.parse(row.detected_items_json) as DetectedFoodItem[],
    totalCalories: row.total_calories,
    totalProteinGrams: row.total_protein_grams,
    totalCarbsGrams: row.total_carbs_grams,
    totalFatGrams: row.total_fat_grams,
    confidence: row.confidence,
    notes: JSON.parse(row.notes_json || "[]") as string[],
    createdAt: normalizeTimestamp(row.created_at)
  };
}

function mealLogFromRow(row: MealLogRow): MealLog {
  return {
    id: row.id,
    userId: row.user_id,
    date: row.date,
    mealType: row.meal_type,
    loggedAt: normalizeTimestamp(row.logged_at),
    source: row.source ?? "manual",
    originalInput: row.original_input,
    imageLocalPath: row.image_local_path,
    items: JSON.parse(row.items_json) as DetectedFoodItem[],
    totalCalories: row.total_calories,
    totalProteinGrams: row.total_protein_grams,
    totalCarbsGrams: row.total_carbs_grams,
    totalFatGrams: row.total_fat_grams,
    createdAt: normalizeTimestamp(row.created_at),
    updatedAt: normalizeTimestamp(row.updated_at)
  };
}

function waterLogFromRow(row: WaterLogRow): WaterLog {
  return {
    id: row.id,
    userId: row.user_id,
    date: row.date,
    litres: row.litres,
    createdAt: normalizeTimestamp(row.created_at)
  };
}

function supplementFromRow(row: SupplementRow): Supplement {
  return {
    id: row.id,
    userId: row.user_id,
    name: row.name,
    dosage: row.dosage,
    frequency: row.frequency,
    timeOfDay: row.time_of_day,
    notes: row.notes,
    isActive: row.is_active === 1,
    createdAt: normalizeTimestamp(row.created_at),
    updatedAt: normalizeTimestamp(row.updated_at)
  };
}

function healthConditionFromRow(row: HealthConditionRow): HealthCondition {
  return {
    id: row.id,
    userId: row.user_id,
    conditionType: row.condition_type,
    customName: row.custom_name,
    notes: row.notes,
    isActive: row.is_active === 1,
    createdAt: normalizeTimestamp(row.created_at),
    updatedAt: normalizeTimestamp(row.updated_at)
  };
}

function normalizeTimestamp(value: string): string {
  if (!value) {
    return value;
  }

  if (value.includes("T") && (value.endsWith("Z") || value.includes("+"))) {
    return value;
  }

  const normalized = value.replace(" ", "T");
  return normalized.endsWith("Z") ? normalized : `${normalized}Z`;
}
