import { PersonalizationContextBuilder } from "./PersonalizationContextBuilder.js";
import { DailyActionPlanService } from "./DailyActionPlanService.js";
import { WeeklyActionPlanService } from "./WeeklyActionPlanService.js";
import type {
  DailyPersonalizedActionPlan,
  DailyPlanLogResponse,
  PlanMealLogRequest,
  WeeklyInsightsResponse,
  WeeklyPersonalizedActionPlan
} from "./actionPlanTypes.js";
import { NutritionRepository } from "../../repositories/nutritionRepository.js";
import { currentIsoDay } from "../../utils/date.js";
import type { MealLog, WaterLog } from "../../types/health.js";
import { estimateMealTotals } from "../nutritionSupport.js";

export class ActionPlanEngine {
  constructor(
    private readonly contextBuilder = new PersonalizationContextBuilder(),
    private readonly dailyActionPlanService = new DailyActionPlanService(),
    private readonly weeklyActionPlanService = new WeeklyActionPlanService(),
    private readonly nutritionRepository = new NutritionRepository()
  ) {}

  getTodayPlan(userId: string, date: string = currentIsoDay()): DailyPersonalizedActionPlan {
    const context = this.contextBuilder.build(userId, date);
    return this.dailyActionPlanService.buildPlan(context, date);
  }

  getWeeklyPlan(userId: string): WeeklyPersonalizedActionPlan {
    const context = this.contextBuilder.build(userId, currentIsoDay());
    const dailyPlan = this.dailyActionPlanService.buildPlan(context);
    return this.weeklyActionPlanService.buildWeeklyPlan(context, dailyPlan);
  }

  getWeeklyInsights(userId: string): WeeklyInsightsResponse {
    const context = this.contextBuilder.build(userId, currentIsoDay());
    const dailyPlan = this.dailyActionPlanService.buildPlan(context);
    const weeklyPlan = this.weeklyActionPlanService.buildWeeklyPlan(context, dailyPlan);
    return this.weeklyActionPlanService.buildWeeklyInsights(context, weeklyPlan);
  }

  logWater(userId: string, litres: number, date: string = currentIsoDay()): { waterLog: WaterLog; plan: DailyPersonalizedActionPlan } {
    const waterLog = this.nutritionRepository.saveWaterLog({
      id: crypto.randomUUID(),
      userId,
      date,
      litres,
      createdAt: new Date().toISOString()
    });
    return {
      waterLog,
      plan: this.getTodayPlan(userId, date)
    };
  }

  logMeal(input: PlanMealLogRequest): DailyPlanLogResponse {
    const totals = estimateMealTotals(input.items);
    const mealLog: MealLog = this.nutritionRepository.saveMealLog({
      id: crypto.randomUUID(),
      userId: input.userId,
      date: input.date,
      mealType: input.mealSlot,
      loggedAt: new Date().toISOString(),
      source: input.source,
      originalInput: input.text ?? null,
      imageLocalPath: null,
      items: input.items,
      totalCalories: totals.totalCalories,
      totalProteinGrams: totals.totalProteinGrams,
      totalCarbsGrams: totals.totalCarbsGrams,
      totalFatGrams: totals.totalFatGrams,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    const plan = this.getTodayPlan(input.userId, input.date);
    return {
      mealLog,
      progress: plan.progress,
      nudges: plan.realTimeNudges
    };
  }
}
