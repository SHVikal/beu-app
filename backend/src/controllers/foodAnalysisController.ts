import type { Request, Response } from "express";
import { OpenAIFoodVisionService } from "../services/OpenAIFoodVisionService.js";
import { OpenAIFoodTextAnalysisService } from "../services/OpenAIFoodTextAnalysisService.js";
import { assertValidFoodUpload, FoodAnalysisHttpError } from "../validators/foodAnalysisValidator.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";

const foodVisionService = new OpenAIFoodVisionService();
const foodTextService = new OpenAIFoodTextAnalysisService();
const asString = (value: string | string[] | undefined): string => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export class FoodAnalysisController {
  async analyzeImage(req: Request, res: Response): Promise<void> {
    try {
      assertValidFoodUpload(req.file);
      const userId = asString(req.body.userId);
      if (!userId) {
        throw new FoodAnalysisHttpError(400, "MISSING_USER_ID", "User id is required.");
      }

      const analysis = await foodVisionService.analyzeMealImage({
        userId,
        fileBuffer: req.file.buffer,
        mimeType: req.file.mimetype,
        filename: req.file.originalname
      });

      res.status(201).json(analysis);
    } catch (error) {
      sendFoodAnalysisError(res, error);
    }
  }

  async analyzeText(req: Request, res: Response): Promise<void> {
    try {
      const analysis = await foodTextService.analyzeMealDescription({
        userId: asString(req.body.userId),
        description: asString(req.body.description),
        mealType: asString(req.body.mealType) as "breakfast" | "lunch" | "dinner" | "snack" | "unknown",
        dietPreference: asString(req.body.dietPreference) as "indian_vegetarian" | "vegetarian" | "vegan" | "no_preference"
      });

      res.status(201).json(analysis);
    } catch (error) {
      sendFoodAnalysisError(res, error);
    }
  }

  updateAnalysisItems(req: Request, res: Response): void {
    try {
      const analysis = foodVisionService.updateDetectedItems(
        asString(req.params.analysisId),
        asString(req.body.userId),
        req.body.items,
        req.body.imageLocalPath
      );
      res.json(analysis);
    } catch (error) {
      sendFoodAnalysisError(res, error);
    }
  }
}

function sendFoodAnalysisError(res: Response, error: unknown): void {
  if (error instanceof FoodAnalysisHttpError) {
    res.status(error.statusCode).json({
      error: true,
      code: error.code,
      message: error.message
    });
    return;
  }

  res.status(500).json({
    error: true,
    code: FOOD_ANALYSIS_ERROR_CODES.imageAnalysisFailed,
    message: "Meal analysis is unavailable right now. Please try again."
  });
}
