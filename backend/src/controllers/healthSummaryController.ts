import type { Request, Response } from "express";
import { HealthSummaryService } from "../services/healthSummaryService.js";

const healthSummaryService = new HealthSummaryService();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class HealthSummaryController {
  create(req: Request, res: Response): void {
    const saved = healthSummaryService.save(req.body);
    res.status(201).json(saved);
  }

  getDaily(req: Request, res: Response): void {
    const summary = healthSummaryService.getDaily(asString(req.params.userId), asString(req.params.date));
    if (!summary) {
      res.status(404).json({ error: "NotFound", message: "Health summary not found." });
      return;
    }
    res.json(summary);
  }

  getRange(req: Request, res: Response): void {
    const days = Number(req.query.days ?? 7);
    const userId = asString(req.params.userId);
    const summaries = healthSummaryService.getRange(userId, days);
    res.json({
      userId,
      days,
      summaries
    });
  }
}
