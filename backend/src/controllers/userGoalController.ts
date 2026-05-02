import type { Request, Response } from "express";
import { UserGoalService } from "../services/userGoalService.js";

const userGoalService = new UserGoalService();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class UserGoalController {
  create(req: Request, res: Response): void {
    const saved = userGoalService.save(req.body);
    res.status(201).json(saved);
  }

  getByUserId(req: Request, res: Response): void {
    const goal = userGoalService.getByUserId(asString(req.params.userId));
    if (!goal) {
      res.status(404).json({ error: "NotFound", message: "User goal not found." });
      return;
    }
    res.json(goal);
  }
}
