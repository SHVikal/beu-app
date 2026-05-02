import type { Request, Response } from "express";
import { NutritionService } from "../services/nutritionService.js";

const nutritionService = new NutritionService();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class NutritionController {
  createProfile(req: Request, res: Response): void {
    const profile = nutritionService.saveProfile(req.body);
    res.status(201).json(profile);
  }

  updateProfile(req: Request, res: Response): void {
    const profile = nutritionService.saveProfile({
      ...req.body,
      userId: asString(req.params.userId)
    });
    res.json(profile);
  }

  getProfile(req: Request, res: Response): void {
    const profile = nutritionService.getProfile(asString(req.params.userId));
    if (!profile) {
      res.status(404).json({ error: "NotFound", message: "Nutrition profile not found." });
      return;
    }
    res.json(profile);
  }

  saveMealLog(req: Request, res: Response): void {
    const mealLog = nutritionService.saveMealLog({
      ...req.body,
      id: req.body.id ?? crypto.randomUUID()
    });
    res.status(201).json(mealLog);
  }

  updateMealLog(req: Request, res: Response): void {
    const mealLog = nutritionService.updateMealLog(asString(req.params.mealLogId), req.body);
    res.json(mealLog);
  }

  getMealLogsForDate(req: Request, res: Response): void {
    const userId = asString(req.params.userId);
    const date = asString(req.params.date);
    const logs = nutritionService.getMealLogsByDate(userId, date);
    res.json({
      userId,
      date,
      meals: logs
    });
  }

  deleteMealLog(req: Request, res: Response): void {
    const deleted = nutritionService.deleteMealLog(asString(req.params.mealLogId));
    if (!deleted) {
      res.status(404).json({ error: "NotFound", message: "Meal log not found." });
      return;
    }
    res.status(204).send();
  }

  getDailyProgress(req: Request, res: Response): void {
    const progress = nutritionService.getDailyProgress(asString(req.params.userId), asString(req.params.date));
    res.json(progress);
  }

  getWeeklySummary(req: Request, res: Response): void {
    const summary = nutritionService.getWeeklySummary(asString(req.params.userId));
    res.json(summary);
  }

  createSupplement(req: Request, res: Response): void {
    const supplement = nutritionService.saveSupplement({
      ...req.body,
      id: req.body.id ?? crypto.randomUUID()
    });
    res.status(201).json(supplement);
  }

  getSupplements(req: Request, res: Response): void {
    const supplements = nutritionService.listSupplements(asString(req.params.userId));
    res.json({ supplements });
  }

  updateSupplement(req: Request, res: Response): void {
    const supplement = nutritionService.saveSupplement({
      ...req.body,
      id: asString(req.params.supplementId)
    });
    res.json(supplement);
  }

  deleteSupplement(req: Request, res: Response): void {
    const deleted = nutritionService.deleteSupplement(asString(req.params.supplementId));
    if (!deleted) {
      res.status(404).json({ error: "NotFound", message: "Supplement not found." });
      return;
    }
    res.status(204).send();
  }

  createHealthCondition(req: Request, res: Response): void {
    const condition = nutritionService.saveHealthCondition({
      ...req.body,
      id: req.body.id ?? crypto.randomUUID()
    });
    res.status(201).json(condition);
  }

  getHealthConditions(req: Request, res: Response): void {
    const conditions = nutritionService.listHealthConditions(asString(req.params.userId));
    res.json({ conditions });
  }

  updateHealthCondition(req: Request, res: Response): void {
    const condition = nutritionService.saveHealthCondition({
      ...req.body,
      id: asString(req.params.conditionId)
    });
    res.json(condition);
  }

  deleteHealthCondition(req: Request, res: Response): void {
    const deleted = nutritionService.deleteHealthCondition(asString(req.params.conditionId));
    if (!deleted) {
      res.status(404).json({ error: "NotFound", message: "Health condition not found." });
      return;
    }
    res.status(204).send();
  }
}
