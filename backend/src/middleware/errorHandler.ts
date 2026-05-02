import type { NextFunction, Request, Response } from "express";
import multer from "multer";
import { FoodAnalysisHttpError } from "../validators/foodAnalysisValidator.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";
import { env } from "../config/env.js";

export function errorHandler(
  error: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (error instanceof FoodAnalysisHttpError) {
    res.status(error.statusCode).json({
      error: true,
      code: error.code,
      message: error.message
    });
    return;
  }

  if (error instanceof multer.MulterError) {
    const message = error.code === "LIMIT_FILE_SIZE"
      ? "This image is too large. Please upload a photo under 10MB."
      : "We could not process that meal image. Please try another photo.";
    const code = error.code === "LIMIT_FILE_SIZE"
      ? FOOD_ANALYSIS_ERROR_CODES.imageTooLarge
      : FOOD_ANALYSIS_ERROR_CODES.imageAnalysisFailed;
    res.status(error.code === "LIMIT_FILE_SIZE" ? 413 : 400).json({
      error: true,
      code,
      message
    });
    return;
  }

  const statusCode = error.message.includes("No health summary found") ? 404 : 500;
  res.status(statusCode).json({
    error: error.name || "InternalServerError",
    message: statusCode >= 500
      ? "Something went wrong on the server."
      : error.message,
    ...(env.nodeEnv !== "production" ? { details: error.message } : {})
  });
}
