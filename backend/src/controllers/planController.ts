import type { Request, Response } from "express";
import { ActionPlanEngine } from "../services/actionPlanEngine/ActionPlanEngine.js";
import { currentIsoDay } from "../utils/date.js";

const engine = new ActionPlanEngine();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class PlanController {
  getTodayPlan(req: Request, res: Response): void {
    const userId = asString(req.params.userId);
    res.json(engine.getTodayPlan(userId));
  }

  getWeeklyPlan(req: Request, res: Response): void {
    const userId = asString(req.params.userId);
    res.json(engine.getWeeklyPlan(userId));
  }

  getWeeklyInsights(req: Request, res: Response): void {
    const userId = asString(req.params.userId);
    res.json(engine.getWeeklyInsights(userId));
  }

  logWater(req: Request, res: Response): void {
    const userId = asString(req.body.userId);
    const litres = Number(req.body.litres ?? 0);
    const date = asString(req.body.date) || currentIsoDay();
    res.status(201).json(engine.logWater(userId, litres, date));
  }

  logMeal(req: Request, res: Response): void {
    const response = engine.logMeal({
      ...req.body,
      userId: asString(req.body.userId),
      mealSlot: asString(req.body.mealSlot) as "breakfast" | "lunch" | "dinner" | "snack",
      source: asString(req.body.source) as "photo" | "text",
      date: asString(req.body.date) || currentIsoDay()
    });
    res.status(201).json(response);
  }
}
