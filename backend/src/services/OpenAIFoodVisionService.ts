import OpenAI from "openai";
import { openAIConfig } from "../config/openai.js";
import type {
  FoodImageAnalysisResponse,
  FoodImageUploadInput,
  OpenAIFoodAnalysisResult,
  PersistedFoodAnalysisInput
} from "../types/foodAnalysis.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";
import type { AnalysisConfidence, DetectedFoodItem } from "../types/health.js";
import { NutritionRepository } from "../repositories/nutritionRepository.js";
import {
  FOOD_IMAGE_ANALYSIS_JSON_SCHEMA,
  FoodAnalysisHttpError,
  openAIFoodAnalysisSchema
} from "../validators/foodAnalysisValidator.js";

const FOOD_ANALYSIS_PROMPT = `You are a food image analysis assistant for a wellness app called BeU.

Analyze the uploaded meal photo.

Your task:
1. Identify visible food items.
2. Estimate portion size for each item.
3. Estimate calories, protein, carbs, and fat for each item.
4. Return only structured JSON matching the schema.
5. Be conservative and honest. If unsure, use lower confidence.
6. Do not invent hidden ingredients.
7. If the food item is unclear, name it generally, for example "mixed curry", "rice dish", "fried snack", or "unknown sauce".
8. Nutrition values are estimates, not medical advice.
9. Include a short notes array reminding the user to confirm items and portions.
10. Do not include medical claims.

Important:
- If multiple items are visible, split them into separate detected items.
- If portion size is uncertain, estimate quantityGrams and set confidence to medium or low.
- If image does not contain food, return empty detectedItems and confidence low.`;

export class OpenAIFoodVisionService {
  private readonly client: OpenAI | null;

  constructor(
    private readonly repository = new NutritionRepository(),
    client: OpenAI | null = openAIConfig.apiKey
      ? new OpenAI({ apiKey: openAIConfig.apiKey })
      : null
  ) {
    this.client = client;
  }

  async analyzeMealImage(input: FoodImageUploadInput): Promise<FoodImageAnalysisResponse> {
    if (!this.client) {
      throw new FoodAnalysisHttpError(
        500,
        FOOD_ANALYSIS_ERROR_CODES.openAIUnavailable,
        "Meal photo analysis is not configured on the server."
      );
    }

    try {
      const response = await this.client.responses.create({
        model: openAIConfig.visionModel,
        input: [{
          role: "user",
          content: [
            { type: "input_text", text: FOOD_ANALYSIS_PROMPT },
            { type: "input_image", image_url: toDataUrl(input.fileBuffer, input.mimeType), detail: "low" }
          ]
        }],
        text: {
          format: {
            type: "json_schema",
            name: "food_image_analysis",
            schema: FOOD_IMAGE_ANALYSIS_JSON_SCHEMA,
            strict: true
          }
        }
      });

      const outputText = response.output_text;
      if (!outputText) {
        throw new Error("Missing structured JSON output.");
      }

      const parsed = openAIFoodAnalysisSchema.parse(JSON.parse(outputText));
      return this.persistAnalysis({
        userId: input.userId,
        inputType: "image",
        originalDescription: null,
        imageLocalPath: null,
        imageRemoteUrl: null,
        detectedItems: parsed.detectedItems.map((item) => sanitizeDetectedItem(item)),
        totalCalories: parsed.totalCalories,
        totalProteinGrams: parsed.totalProteinGrams,
        totalCarbsGrams: parsed.totalCarbsGrams,
        totalFatGrams: parsed.totalFatGrams,
        confidence: parsed.confidence,
        notes: parsed.notes
      });
    } catch (error) {
      if (error instanceof FoodAnalysisHttpError) {
        throw error;
      }

      throw new FoodAnalysisHttpError(
        502,
        FOOD_ANALYSIS_ERROR_CODES.imageAnalysisFailed,
        "We could not analyze this image. Please try another photo."
      );
    }
  }

  updateDetectedItems(analysisId: string, userId: string, items: DetectedFoodItem[], imageLocalPath?: string | null): FoodImageAnalysisResponse {
    const existing = this.repository.getAnalysis(analysisId);
    if (!existing) {
      throw new FoodAnalysisHttpError(404, "ANALYSIS_NOT_FOUND", "Food analysis not found.");
    }
    if (existing.userId !== userId) {
      throw new FoodAnalysisHttpError(403, "ANALYSIS_FORBIDDEN", "Food analysis does not belong to this user.");
    }

    const sanitizedItems = items.map((item) => sanitizeDetectedItem({
      name: item.name,
      estimatedPortion: item.estimatedPortion,
      quantityGrams: item.quantityGrams ?? 0,
      confidence: item.confidence as AnalysisConfidence,
      calories: item.calories,
      proteinGrams: item.proteinGrams,
      carbsGrams: item.carbsGrams,
      fatGrams: item.fatGrams
    }, item.id, item.userConfirmed));
    const totals = recalculateTotals(sanitizedItems);

    const stored = this.repository.saveAnalysis({
      ...existing,
      inputType: existing.inputType,
      originalDescription: existing.originalDescription ?? null,
      imageLocalPath: imageLocalPath ?? existing.imageLocalPath ?? null,
      detectedItems: sanitizedItems,
      totalCalories: totals.totalCalories,
      totalProteinGrams: totals.totalProteinGrams,
      totalCarbsGrams: totals.totalCarbsGrams,
      totalFatGrams: totals.totalFatGrams,
      confidence: deriveOverallConfidence(sanitizedItems),
      notes: normalizeNotes(existing.notes)
    });

    return mapAnalysisResponse(stored);
  }

  private persistAnalysis(input: PersistedFoodAnalysisInput): FoodImageAnalysisResponse {
    const sanitizedItems = input.detectedItems.map((item) =>
      sanitizeDetectedItem(
        {
          name: item.name,
          estimatedPortion: item.estimatedPortion,
          quantityGrams: item.quantityGrams ?? 0,
          confidence: item.confidence,
          calories: item.calories,
          proteinGrams: item.proteinGrams,
          carbsGrams: item.carbsGrams,
          fatGrams: item.fatGrams
        },
        item.id,
        item.userConfirmed
      )
    );
    const totals = recalculateTotals(sanitizedItems);
    const stored = this.repository.saveAnalysis({
      id: crypto.randomUUID(),
      userId: input.userId,
      inputType: input.inputType,
      originalDescription: input.originalDescription ?? null,
      imageLocalPath: input.imageLocalPath ?? null,
      imageRemoteUrl: input.imageRemoteUrl ?? null,
      detectedItems: sanitizedItems,
      totalCalories: totals.totalCalories,
      totalProteinGrams: totals.totalProteinGrams,
      totalCarbsGrams: totals.totalCarbsGrams,
      totalFatGrams: totals.totalFatGrams,
      confidence: sanitizedItems.length > 0 ? deriveOverallConfidence(sanitizedItems) : "low",
      notes: sanitizedItems.length == 0
        ? [
            "We could not clearly identify food in this image. Try another photo or add items manually.",
            "Nutrition values are estimates based on visible food items."
          ]
        : normalizeNotes(input.notes),
      createdAt: new Date().toISOString()
    });

    return mapAnalysisResponse(stored);
  }
}

function toDataUrl(buffer: Buffer, mimeType: string): string {
  return `data:${mimeType};base64,${buffer.toString("base64")}`;
}

function sanitizeDetectedItem(
  item: Partial<OpenAIFoodAnalysisResult["detectedItems"][number]> & { quantityGrams?: number | null },
  id: string = crypto.randomUUID(),
  userConfirmed = false
): DetectedFoodItem {
  return {
    id,
    name: sanitizeString(item.name, "Unknown item"),
    estimatedPortion: sanitizeString(item.estimatedPortion, "Estimated serving"),
    quantityGrams: sanitizeNumber(item.quantityGrams, 0),
    confidence: sanitizeConfidence(item.confidence),
    calories: Math.round(sanitizeNumber(item.calories, 0)),
    proteinGrams: roundOneDecimal(sanitizeNumber(item.proteinGrams, 0)),
    carbsGrams: roundOneDecimal(sanitizeNumber(item.carbsGrams, 0)),
    fatGrams: roundOneDecimal(sanitizeNumber(item.fatGrams, 0)),
    userConfirmed
  };
}

function sanitizeString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function sanitizeNumber(value: unknown, fallback: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return parsed;
}

function sanitizeConfidence(value: unknown): AnalysisConfidence {
  return value === "high" || value === "medium" || value === "low" ? value : "low";
}

function roundOneDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

function recalculateTotals(items: DetectedFoodItem[]) {
  return {
    totalCalories: items.reduce((sum, item) => sum + Math.max(0, item.calories), 0),
    totalProteinGrams: roundOneDecimal(items.reduce((sum, item) => sum + Math.max(0, item.proteinGrams), 0)),
    totalCarbsGrams: roundOneDecimal(items.reduce((sum, item) => sum + Math.max(0, item.carbsGrams), 0)),
    totalFatGrams: roundOneDecimal(items.reduce((sum, item) => sum + Math.max(0, item.fatGrams), 0))
  };
}

function deriveOverallConfidence(items: DetectedFoodItem[]): AnalysisConfidence {
  if (items.some((item) => item.confidence === "low")) {
    return "low";
  }
  if (items.some((item) => item.confidence === "medium")) {
    return "medium";
  }
  return "high";
}

function normalizeNotes(notes: string[] | undefined): string[] {
  const defaultNotes = [
    "Nutrition values are estimates based on visible food items.",
    "Please confirm items and portions before logging."
  ];

  const clean = (notes ?? [])
    .map((note) => note.trim())
    .filter((note) => note.length > 0);

  return clean.length > 0 ? clean.slice(0, 4) : defaultNotes;
}

function mapAnalysisResponse(analysis: {
  id: string;
  userId: string;
  imageLocalPath?: string | null;
  imageRemoteUrl?: string | null;
  inputType?: "image" | "text";
  originalDescription?: string | null;
  detectedItems: DetectedFoodItem[];
  totalCalories: number;
  totalProteinGrams: number;
  totalCarbsGrams: number;
  totalFatGrams: number;
  confidence: AnalysisConfidence;
  notes: string[];
  createdAt?: string;
}): FoodImageAnalysisResponse {
  return {
    analysisId: analysis.id,
    userId: analysis.userId,
    inputType: analysis.inputType ?? "image",
    originalDescription: analysis.originalDescription ?? null,
    imageLocalPath: analysis.imageLocalPath ?? null,
    imageRemoteUrl: analysis.imageRemoteUrl ?? null,
    detectedItems: analysis.detectedItems,
    totalCalories: analysis.totalCalories,
    totalProteinGrams: analysis.totalProteinGrams,
    totalCarbsGrams: analysis.totalCarbsGrams,
    totalFatGrams: analysis.totalFatGrams,
    confidence: analysis.confidence,
    notes: analysis.notes,
    createdAt: analysis.createdAt ?? new Date().toISOString()
  };
}

export const foodAnalysisTestUtils = {
  sanitizeDetectedItem,
  recalculateTotals,
  deriveOverallConfidence,
  normalizeNotes,
  mapAnalysisResponse
};
