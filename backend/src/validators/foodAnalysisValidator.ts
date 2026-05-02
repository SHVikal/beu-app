import { z } from "zod";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";

export const allowedFoodImageMimeTypes = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/heic",
  "image/heif"
]);

export const maxFoodImageBytes = 10 * 1024 * 1024;

export class FoodAnalysisHttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = "FoodAnalysisHttpError";
  }
}

export function assertValidFoodUpload(file: Express.Multer.File | undefined): asserts file is Express.Multer.File {
  if (!file) {
    throw new FoodAnalysisHttpError(
      400,
      FOOD_ANALYSIS_ERROR_CODES.missingImage,
      "Please attach a meal image before analyzing."
    );
  }

  if (!allowedFoodImageMimeTypes.has(file.mimetype)) {
    throw new FoodAnalysisHttpError(
      415,
      FOOD_ANALYSIS_ERROR_CODES.invalidImageType,
      "Please upload a JPG, PNG, or HEIC food photo."
    );
  }

  if (file.size > maxFoodImageBytes) {
    throw new FoodAnalysisHttpError(
      413,
      FOOD_ANALYSIS_ERROR_CODES.imageTooLarge,
      "This image is too large. Please upload a photo under 10MB."
    );
  }
}

const confidenceSchema = z.enum(["high", "medium", "low"]);

export const openAIFoodAnalysisSchema = z.object({
  detectedItems: z.array(z.object({
    name: z.string().catch("Unknown item"),
    estimatedPortion: z.string().catch("Estimated serving"),
    quantityGrams: z.coerce.number().catch(0),
    confidence: confidenceSchema.catch("low"),
    calories: z.coerce.number().catch(0),
    proteinGrams: z.coerce.number().catch(0),
    carbsGrams: z.coerce.number().catch(0),
    fatGrams: z.coerce.number().catch(0)
  })).catch([]),
  totalCalories: z.coerce.number().catch(0),
  totalProteinGrams: z.coerce.number().catch(0),
  totalCarbsGrams: z.coerce.number().catch(0),
  totalFatGrams: z.coerce.number().catch(0),
  confidence: confidenceSchema.catch("low"),
  notes: z.array(z.string()).catch([])
}).strict();

export const FOOD_IMAGE_ANALYSIS_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    detectedItems: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          estimatedPortion: { type: "string" },
          quantityGrams: { type: "number" },
          confidence: { type: "string", enum: ["high", "medium", "low"] },
          calories: { type: "number" },
          proteinGrams: { type: "number" },
          carbsGrams: { type: "number" },
          fatGrams: { type: "number" }
        },
        required: [
          "name",
          "estimatedPortion",
          "quantityGrams",
          "confidence",
          "calories",
          "proteinGrams",
          "carbsGrams",
          "fatGrams"
        ]
      }
    },
    totalCalories: { type: "number" },
    totalProteinGrams: { type: "number" },
    totalCarbsGrams: { type: "number" },
    totalFatGrams: { type: "number" },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    notes: {
      type: "array",
      items: { type: "string" }
    }
  },
  required: [
    "detectedItems",
    "totalCalories",
    "totalProteinGrams",
    "totalCarbsGrams",
    "totalFatGrams",
    "confidence",
    "notes"
  ]
} as const;
