import type { Request, Response } from "express";
import { AppStateService } from "../services/appStateService.js";

const appStateService = new AppStateService();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class AppStateController {
  save(req: Request, res: Response): void {
    const saved = appStateService.save({
      userId: asString(req.params.userId) || req.body.userId,
      payload: req.body.payload ?? {}
    });
    res.status(200).json(saved);
  }

  get(req: Request, res: Response): void {
    const snapshot = appStateService.get(asString(req.params.userId));
    if (!snapshot) {
      res.status(404).json({ error: "NotFound", message: "App state snapshot not found." });
      return;
    }
    res.json(snapshot);
  }
}
