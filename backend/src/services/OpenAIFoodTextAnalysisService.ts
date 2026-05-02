import OpenAI from "openai";
import { openAIConfig } from "../config/openai.js";
import { NutritionRepository } from "../repositories/nutritionRepository.js";
import type {
  FoodImageAnalysisResponse,
  FoodTextAnalysisInput,
  OpenAIFoodAnalysisResult
} from "../types/foodAnalysis.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";
import type { AnalysisConfidence, DetectedFoodItem, FoodImageAnalysis } from "../types/health.js";
import {
  FOOD_IMAGE_ANALYSIS_JSON_SCHEMA,
  FoodAnalysisHttpError,
  openAIFoodAnalysisSchema
} from "../validators/foodAnalysisValidator.js";

const FOOD_TEXT_ANALYSIS_PROMPT = `You are a nutrition estimation assistant for BeU, a wellness app.

Analyze the user's meal description.

Your task:
1. Identify each food item mentioned.
2. Estimate the portion size for each item.
3. Estimate quantity in grams where possible.
4. Estimate calories, protein, carbs, and fat for each item.
5. Return strict JSON only using the provided schema.
6. Be conservative and honest.
7. If portion is unclear, use a common serving size and mark confidence as medium or low.
8. Do not invent foods not mentioned.
9. For Indian meals, understand common foods such as roti, chapati, dal, sabzi, paneer, tofu, curd, rice, idli, dosa, poha, upma, chole, rajma, khichdi, sprouts, soya chunks, paratha.
10. Values are estimates, not medical advice.
11. User must confirm items and portions before logging.

If the description is vague, such as "normal lunch" or "light dinner":
- Return low confidence.
- Use generic items only if reasonably inferable.
- Add a note asking user to edit items.`;

export class OpenAIFoodTextAnalysisService {
  private readonly client: OpenAI | null;

  constructor(
    private readonly repository = new NutritionRepository(),
    client: OpenAI | null = openAIConfig.apiKey
      ? new OpenAI({ apiKey: openAIConfig.apiKey })
      : null
  ) {
    this.client = client;
  }

  async analyzeMealDescription(input: FoodTextAnalysisInput): Promise<FoodImageAnalysisResponse> {
    if (!this.client) {
      throw new FoodAnalysisHttpError(
        500,
        FOOD_ANALYSIS_ERROR_CODES.openAIUnavailable,
        "Meal analysis is not configured on the server."
      );
    }

    try {
      const response = await this.client.responses.create({
        model: openAIConfig.textModel,
        input: [{
          role: "user",
          content: [{
            type: "input_text",
            text: `${FOOD_TEXT_ANALYSIS_PROMPT}

User meal description: ${input.description}
Meal type: ${input.mealType}
Diet preference: ${input.dietPreference}`
          }]
        }],
        text: {
          format: {
            type: "json_schema",
            name: "food_text_analysis",
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
      return persistTextAnalysis(this.repository, input, parsed);
    } catch (error) {
      if (error instanceof FoodAnalysisHttpError) {
        throw error;
      }

      throw new FoodAnalysisHttpError(
        502,
        FOOD_ANALYSIS_ERROR_CODES.textAnalysisFailed,
        "We couldn’t estimate this meal. Try adding more detail or log items manually."
      );
    }
  }
}

function persistTextAnalysis(
  repository: NutritionRepository,
  input: FoodTextAnalysisInput,
  parsed: OpenAIFoodAnalysisResult
): FoodImageAnalysisResponse {
  const sanitizedItems = parsed.detectedItems.map((item) => sanitizeDetectedItem(item));
  const totals = recalculateTotals(sanitizedItems);
  const vagueDescription = input.description.trim().split(/\s+/).length < 3;
  const notes = normalizeNotes(parsed.notes, vagueDescription);

  const stored = repository.saveAnalysis({
    id: crypto.randomUUID(),
    userId: input.userId,
    inputType: "text",
    originalDescription: input.description.trim(),
    imageLocalPath: null,
    imageRemoteUrl: null,
    detectedItems: sanitizedItems,
    totalCalories: totals.totalCalories,
    totalProteinGrams: totals.totalProteinGrams,
    totalCarbsGrams: totals.totalCarbsGrams,
    totalFatGrams: totals.totalFatGrams,
    confidence: sanitizedItems.length > 0 ? deriveOverallConfidence(sanitizedItems) : "low",
    notes,
    createdAt: new Date().toISOString()
  } satisfies FoodImageAnalysis);

  return {
    analysisId: stored.id,
    userId: stored.userId,
    inputType: stored.inputType,
    originalDescription: stored.originalDescription ?? null,
    imageLocalPath: stored.imageLocalPath ?? null,
    imageRemoteUrl: stored.imageRemoteUrl ?? null,
    detectedItems: stored.detectedItems,
    totalCalories: stored.totalCalories,
    totalProteinGrams: stored.totalProteinGrams,
    totalCarbsGrams: stored.totalCarbsGrams,
    totalFatGrams: stored.totalFatGrams,
    confidence: stored.confidence,
    notes: stored.notes,
    createdAt: stored.createdAt ?? new Date().toISOString()
  };
}

function sanitizeDetectedItem(
  item: Partial<OpenAIFoodAnalysisResult["detectedItems"][number]>,
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

function normalizeNotes(notes: string[] | undefined, vagueDescription: boolean): string[] {
  const clean = (notes ?? [])
    .map((note) => note.trim())
    .filter((note) => note.length > 0);

  const defaults = [
    "Nutrition values are estimates based on the described meal.",
    "Please confirm items and portions before logging."
  ];

  if (vagueDescription) {
    defaults.push("Add portions like number of rotis, bowl size, or serving size to improve the estimate.");
  }

  return clean.length > 0 ? clean.slice(0, 4) : defaults;
}
