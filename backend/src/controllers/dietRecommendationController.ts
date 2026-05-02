import type { Request, Response } from "express";
import { DietRecommendationService } from "../services/dietRecommendationService.js";

const dietRecommendationService = new DietRecommendationService();

export class DietRecommendationController {
  create(req: Request, res: Response): void {
    const recommendation = dietRecommendationService.generate(req.body);
    res.status(200).json(recommendation);
  }
}
