import test, { beforeEach } from "node:test";
import assert from "node:assert/strict";
import { db } from "../db/database.js";
import { NutritionRepository } from "../repositories/nutritionRepository.js";
import { HealthSummaryRepository } from "../repositories/healthSummaryRepository.js";
import { ActionPlanEngine } from "../services/actionPlanEngine/ActionPlanEngine.js";
import { FORBIDDEN_PLAN_SUBSTRINGS } from "../services/actionPlanEngine/actionPlanTypes.js";
import type {
  DetectedFoodItem,
  HealthCondition,
  HealthSummary,
  MealLog,
  Supplement,
  UserNutritionProfile
} from "../types/health.js";

const nutritionRepository = new NutritionRepository();
const healthSummaryRepository = new HealthSummaryRepository();
const engine = new ActionPlanEngine();
const today = "2026-05-01";

beforeEach(() => {
  db.exec(`
    DELETE FROM water_logs;
    DELETE FROM meal_logs;
    DELETE FROM food_image_analyses;
    DELETE FROM supplements;
    DELETE FROM health_conditions;
    DELETE FROM user_nutrition_profiles;
    DELETE FROM health_summaries;
  `);
});

function makeProfile(overrides: Partial<UserNutritionProfile> = {}): UserNutritionProfile {
  return {
    userId: "demo-user",
    age: 32,
    sex: "female",
    heightCm: 168,
    currentWeightKg: 72,
    targetWeightKg: 66,
    goalType: "lose_weight",
    dailyCalorieTarget: 1850,
    dailyProteinTargetGrams: 125,
    dailyCarbTargetGrams: 185,
    dailyFatTargetGrams: 62,
    targetTimeline: "12 weeks",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...overrides
  };
}

function makeSummary(date: string, overrides: Partial<HealthSummary> = {}): HealthSummary {
  return {
    userId: "demo-user",
    date,
    steps: 7600,
    activeEnergyKcal: 360,
    basalEnergyKcal: 1480,
    workoutCount: 1,
    workoutMinutes: 35,
    workoutEnergyKcal: 220,
    totalEnergyBurnedKcal: 1840,
    estimatedTotalBurnKcal: 1840,
    sleepHours: 7.4,
    restingHeartRateBpm: 58,
    hrvMs: 42,
    weightKg: 72,
    heightCm: 168,
    ...overrides
  };
}

function makeMealLog(overrides: Partial<MealLog> = {}): MealLog {
  const item: DetectedFoodItem = {
    id: crypto.randomUUID(),
    name: "Chicken bowl",
    estimatedPortion: "1 bowl",
    quantityGrams: 220,
    confidence: "medium",
    calories: 620,
    proteinGrams: 28,
    carbsGrams: 55,
    fatGrams: 20,
    userConfirmed: true
  };
  return {
    id: crypto.randomUUID(),
    userId: "demo-user",
    date: today,
    mealType: "lunch",
    ...overrides,
    loggedAt: overrides.loggedAt ?? new Date().toISOString(),
    source: overrides.source ?? "manual",
    originalInput: overrides.originalInput ?? null,
    imageLocalPath: overrides.imageLocalPath ?? null,
    items: overrides.items ?? [item],
    totalCalories: overrides.totalCalories ?? item.calories,
    totalProteinGrams: overrides.totalProteinGrams ?? item.proteinGrams,
    totalCarbsGrams: overrides.totalCarbsGrams ?? item.carbsGrams,
    totalFatGrams: overrides.totalFatGrams ?? item.fatGrams,
    createdAt: overrides.createdAt ?? new Date().toISOString(),
    updatedAt: overrides.updatedAt ?? new Date().toISOString()
  };
}

function saveWeek(overrides: Array<Partial<HealthSummary>> = []): void {
  const dates = ["2026-04-25", "2026-04-26", "2026-04-27", "2026-04-28", "2026-04-29", "2026-04-30", "2026-05-01"];
  dates.forEach((date, index) => {
    healthSummaryRepository.save(makeSummary(date, overrides[index] ?? {}));
  });
}

function saveCondition(conditionType: HealthCondition["conditionType"]): void {
  const condition: HealthCondition = {
    id: crypto.randomUUID(),
    userId: "demo-user",
    conditionType,
    customName: null,
    notes: null,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  nutritionRepository.saveHealthCondition(condition);
}

function saveSupplement(overrides: Partial<Supplement> = {}): void {
  const supplement: Supplement = {
    id: crypto.randomUUID(),
    userId: "demo-user",
    name: "Magnesium",
    dosage: "200mg",
    frequency: "daily",
    timeOfDay: "evening",
    notes: null,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...overrides
  };
  nutritionRepository.saveSupplement(supplement);
}

test("fat loss plus poor sleep avoids aggressive deficit and keeps recovery in focus", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([
    {},
    {},
    {},
    {},
    {},
    {},
    { sleepHours: 5.7, steps: 8200, activeEnergyKcal: 410 }
  ]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.notEqual(plan.calorieDirection, "Slight surplus");
  assert.equal(plan.priorityActions[0]?.category, "recovery");
  assert.match(plan.planSummary.toLowerCase(), /recovery|light/);
});

test("muscle gain plus high readiness and low strength history requires strength and raises protein", () => {
  nutritionRepository.saveProfile(makeProfile({
    sex: "male",
    currentWeightKg: 80,
    targetWeightKg: 83,
    goalType: "gain_muscle",
    dailyCalorieTarget: 2400,
    dailyProteinTargetGrams: 160
  }));
  saveWeek([
    { sleepHours: 8.1, workoutCount: 0, workoutMinutes: 0, steps: 7000, activeEnergyKcal: 320, hrvMs: 48, restingHeartRateBpm: 55 },
    { sleepHours: 8.0, workoutCount: 0, workoutMinutes: 0, steps: 7200, activeEnergyKcal: 330, hrvMs: 47, restingHeartRateBpm: 56 },
    { sleepHours: 8.3, workoutCount: 0, workoutMinutes: 0, steps: 7100, activeEnergyKcal: 340, hrvMs: 49, restingHeartRateBpm: 55 },
    { sleepHours: 8.0, workoutCount: 0, workoutMinutes: 0, steps: 7300, activeEnergyKcal: 340, hrvMs: 50, restingHeartRateBpm: 55 },
    { sleepHours: 8.1, workoutCount: 0, workoutMinutes: 0, steps: 7500, activeEnergyKcal: 350, hrvMs: 51, restingHeartRateBpm: 54 },
    { sleepHours: 8.2, workoutCount: 0, workoutMinutes: 0, steps: 7600, activeEnergyKcal: 360, hrvMs: 50, restingHeartRateBpm: 54 },
    { sleepHours: 8.4, workoutCount: 0, workoutMinutes: 0, steps: 7700, activeEnergyKcal: 370, hrvMs: 53, restingHeartRateBpm: 53 }
  ]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.targets.strengthTraining.recommendation, "required");
  assert.ok(plan.targets.proteinGrams >= 150);
});

test("pcos plus fat loss keeps wording moderate and adds balanced-meals note", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveCondition("pcos");
  saveWeek();

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.healthContextNotes.some((item) => item.includes("PCOS")));
  const allText = JSON.stringify(plan).toLowerCase();
  assert.equal(allText.includes("aggressive deficit"), false);
});

test("pregnancy removes deficit and sets strong safety note", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveCondition("pregnancy");
  saveWeek();

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.calorieDirection, "Maintain");
  assert.match(plan.safetyNote, /Pregnancy nutrition needs/);
});

test("eating disorder history removes weight-loss pressure language", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveCondition("eating_disorder_history");
  saveWeek();

  const plan = engine.getTodayPlan("demo-user", today);
  const text = [
    plan.planSummary,
    ...plan.priorityActions.map((item) => item.title),
    ...plan.priorityActions.map((item) => item.description),
    ...plan.explanation
  ].join(" ").toLowerCase();
  assert.equal(text.includes("weight loss"), false);
  assert.equal(text.includes("deficit"), false);
});

test("large protein gap creates protein nudge", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek();
  nutritionRepository.saveMealLog(makeMealLog({
    totalCalories: 420,
    totalProteinGrams: 14
  }));

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("protein")));
});

test("calorie overage creates course correction nudge", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek();
  nutritionRepository.saveMealLog(makeMealLog({ totalCalories: 1200, totalProteinGrams: 18 }));
  nutritionRepository.saveMealLog(makeMealLog({ totalCalories: 900, totalProteinGrams: 20, mealType: "dinner" }));

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("activity is behind")));
});

test("low readiness makes recovery the first priority action", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([
    {},
    {},
    {},
    {},
    {},
    {},
    { sleepHours: 5.5, restingHeartRateBpm: 64, hrvMs: 28, activeEnergyKcal: 420, steps: 8300 }
  ]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.targets.strengthTraining.recommendation, "rest");
  assert.equal(plan.priorityActions[0]?.category, "recovery");
});

test("missing HRV still returns a plan", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([
    {},
    {},
    {},
    {},
    {},
    {},
    { hrvMs: null }
  ]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.targets.calories > 0);
  assert.ok(plan.explanation.length > 0);
});

test("missing profile returns onboardingRequired", () => {
  saveWeek();
  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.onboardingRequired, true);
});

test("estimated total burn uses basal plus active energy when both are present", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([{}, {}, {}, {}, {}, {}, { activeEnergyKcal: 420, basalEnergyKcal: 1520, estimatedTotalBurnKcal: 1940 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.energyBalance.activeEnergyBurned, 420);
  assert.equal(plan.energyBalance.basalEnergyBurned, 1520);
  assert.equal(plan.energyBalance.estimatedTotalBurn, 1940);
});

test("basal missing falls back to estimated BMR plus active energy", () => {
  nutritionRepository.saveProfile(makeProfile({ age: 30, heightCm: 165, currentWeightKg: 70 }));
  saveWeek([{}, {}, {}, {}, {}, {}, { activeEnergyKcal: 400, basalEnergyKcal: null, totalEnergyBurnedKcal: null, estimatedTotalBurnKcal: 0 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.energyBalance.estimatedTotalBurn > 1400);
  assert.equal(plan.energyBalance.basalEnergyBurned, null);
});

test("workout calories are shown separately and not double-counted", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([{}, {}, {}, {}, {}, {}, { activeEnergyKcal: 500, basalEnergyKcal: 1500, workoutEnergyKcal: 320, totalEnergyBurnedKcal: 2000, estimatedTotalBurnKcal: 2000 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.energyBalance.workoutEnergyBurned, 320);
  assert.equal(plan.energyBalance.estimatedTotalBurn, 2000);
});

test("fat loss plus burn behind and moderate readiness creates a walking nudge", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([{}, {}, {}, {}, {}, {}, { steps: 3200, activeEnergyKcal: 180, basalEnergyKcal: 1450, estimatedTotalBurnKcal: 1630, sleepHours: 7.1, hrvMs: 41, restingHeartRateBpm: 59 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("burn target")));
});

test("low readiness plus burn behind keeps recovery first and avoids aggressive burn push", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([{}, {}, {}, {}, {}, {}, { steps: 2800, activeEnergyKcal: 160, basalEnergyKcal: 1450, estimatedTotalBurnKcal: 1610, sleepHours: 5.6, hrvMs: 24, restingHeartRateBpm: 66 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.equal(plan.targets.strengthTraining.recommendation, "rest");
  assert.equal(plan.priorityActions[0]?.category, "recovery");
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("don't chase burn aggressively")));
});

test("burn target met removes extra cardio pressure", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek([{}, {}, {}, {}, {}, {}, { steps: 9800, activeEnergyKcal: 760, basalEnergyKcal: 1550, estimatedTotalBurnKcal: 2310, sleepHours: 7.6, hrvMs: 46, restingHeartRateBpm: 57 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("burn target")));
  assert.match(plan.planSummary.toLowerCase(), /optional|on track/);
});

test("muscle gain plus workout completed creates protein refuel nudge without excessive cardio pressure", () => {
  nutritionRepository.saveProfile(makeProfile({
    sex: "male",
    currentWeightKg: 80,
    targetWeightKg: 82,
    goalType: "gain_muscle",
    dailyCalorieTarget: 2400,
    dailyProteinTargetGrams: 160
  }));
  saveWeek([{}, {}, {}, {}, {}, {}, { steps: 6400, activeEnergyKcal: 520, basalEnergyKcal: 1700, workoutEnergyKcal: 340, estimatedTotalBurnKcal: 2220, workoutCount: 1, workoutMinutes: 48 }]);

  const plan = engine.getTodayPlan("demo-user", today);
  assert.ok(plan.realTimeNudges.some((item) => item.message.toLowerCase().includes("protein-led")));
  assert.ok(plan.targets.cardioMinutes <= 15);
});

test("supplement reminders never include dosage or interaction language", () => {
  nutritionRepository.saveProfile(makeProfile());
  saveWeek();
  saveSupplement({ name: "Vitamin D", timeOfDay: "evening", dosage: "2000 IU" });

  const plan = engine.getTodayPlan("demo-user", today);
  for (const reminder of plan.supplementReminders) {
    const lowered = reminder.toLowerCase();
    assert.equal(lowered.includes("dosage"), false);
    assert.equal(lowered.includes("interaction"), false);
    assert.equal(lowered.includes("2000"), false);
    assert.equal(lowered.includes("should"), false);
  }
});

test("language guard blocks forbidden medical phrasing across plan and nudges", () => {
  nutritionRepository.saveProfile(makeProfile({
    goalType: "gain_muscle",
    sex: "male",
    currentWeightKg: 84,
    dailyCalorieTarget: 2500,
    dailyProteinTargetGrams: 160
  }));
  saveCondition("pcos");
  saveCondition("diabetes");
  saveWeek();
  nutritionRepository.saveMealLog(makeMealLog({ totalCalories: 2600, totalProteinGrams: 40 }));

  const plan = engine.getTodayPlan("demo-user", today);
  const weeklyPlan = engine.getWeeklyPlan("demo-user");
  const weeklyInsights = engine.getWeeklyInsights("demo-user");

  const corpus = [
    plan.planSummary,
    ...plan.priorityActions.flatMap((item) => [item.title, item.description]),
    ...plan.realTimeNudges.flatMap((item) => [item.message, item.reason]),
    ...plan.supplementReminders,
    ...plan.healthContextNotes,
    ...plan.explanation,
    plan.safetyNote,
    ...weeklyPlan.weeklyFocus,
    ...weeklyPlan.recommendedAdjustments.flatMap((item) => [item.title, item.description, item.reason]),
    ...weeklyPlan.explanation,
    weeklyPlan.safetyNote,
    ...weeklyInsights.cards.flatMap((item) => [item.kicker, item.sentence]),
    ...weeklyInsights.actions.flatMap((item) => [item.title, item.description]),
    weeklyInsights.disclaimer
  ].join(" ").toLowerCase();

  for (const forbidden of FORBIDDEN_PLAN_SUBSTRINGS) {
    assert.equal(corpus.includes(forbidden), false, `Unexpected forbidden term: ${forbidden}`);
  }
});
