import test from "node:test";
import assert from "node:assert/strict";
import { OpenAIFoodVisionService, foodAnalysisTestUtils } from "../services/OpenAIFoodVisionService.js";
import { OpenAIFoodTextAnalysisService } from "../services/OpenAIFoodTextAnalysisService.js";
import { assertValidFoodUpload, FoodAnalysisHttpError } from "../validators/foodAnalysisValidator.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";
import type { OpenAIFoodAnalysisResult } from "../types/foodAnalysis.js";
import type { FoodImageAnalysis } from "../types/health.js";

class MockRepository {
  saved: FoodImageAnalysis | null = null;

  saveAnalysis(analysis: FoodImageAnalysis): FoodImageAnalysis {
    this.saved = analysis;
    return analysis;
  }

  getAnalysis(id: string): FoodImageAnalysis | null {
    return this.saved?.id === id ? this.saved : null;
  }
}

class StubResponsesClient {
  constructor(private readonly payload: unknown) {}

  responses = {
    create: async () => ({
      output_text: JSON.stringify(this.payload)
    })
  };
}

test("missing image returns validation error", () => {
  assert.throws(
    () => assertValidFoodUpload(undefined),
    (error: unknown) =>
      error instanceof FoodAnalysisHttpError &&
      error.code === FOOD_ANALYSIS_ERROR_CODES.missingImage
  );
});

test("invalid file type returns validation error", () => {
  assert.throws(
    () => assertValidFoodUpload({
      fieldname: "image",
      originalname: "meal.gif",
      encoding: "7bit",
      mimetype: "image/gif",
      size: 100,
      buffer: Buffer.from("x")
    } as Express.Multer.File),
    (error: unknown) =>
      error instanceof FoodAnalysisHttpError &&
      error.code === FOOD_ANALYSIS_ERROR_CODES.invalidImageType
  );
});

test("OpenAI response maps to food analysis response", async () => {
  const repository = new MockRepository();
  const service = new OpenAIFoodVisionService(
    repository as never,
    new StubResponsesClient({
      detectedItems: [
        {
          name: "Grilled chicken",
          estimatedPortion: "150g",
          quantityGrams: 150,
          confidence: "high",
          calories: 250,
          proteinGrams: 32.4,
          carbsGrams: 4.2,
          fatGrams: 8.1
        }
      ],
      totalCalories: 999,
      totalProteinGrams: 999,
      totalCarbsGrams: 999,
      totalFatGrams: 999,
      confidence: "medium",
      notes: [
        "Nutrition values are estimates based on visible food items.",
        "Please confirm items and portions before logging."
      ]
    }) as never
  );

  const analysis = await service.analyzeMealImage({
    userId: "demo-user",
    fileBuffer: Buffer.from("fake"),
    mimeType: "image/jpeg",
    filename: "meal.jpg"
  });

  assert.equal(analysis.analysisId.length > 0, true);
  assert.equal(analysis.detectedItems.length, 1);
  assert.equal(analysis.detectedItems[0]?.userConfirmed, false);
  assert.equal(analysis.inputType, "image");
  assert.equal(analysis.totalCalories, 250);
  assert.equal(analysis.totalProteinGrams, 32.4);
});

test("text analysis response includes original description", async () => {
  const repository = new MockRepository();
  const service = new OpenAIFoodTextAnalysisService(
    repository as never,
    new StubResponsesClient({
      detectedItems: [
        {
          name: "Roti",
          estimatedPortion: "2 medium",
          quantityGrams: 100,
          confidence: "medium",
          calories: 220,
          proteinGrams: 6,
          carbsGrams: 42,
          fatGrams: 2
        }
      ],
      totalCalories: 220,
      totalProteinGrams: 6,
      totalCarbsGrams: 42,
      totalFatGrams: 2,
      confidence: "medium",
      notes: []
    }) as never
  );

  const analysis = await service.analyzeMealDescription({
    userId: "demo-user",
    description: "2 rotis",
    mealType: "lunch",
    dietPreference: "indian_vegetarian"
  });

  assert.equal(analysis.inputType, "text");
  assert.equal(analysis.originalDescription, "2 rotis");
  assert.equal(analysis.detectedItems[0]?.userConfirmed, false);
});

test("negative calories and macros are sanitized", () => {
  const item = foodAnalysisTestUtils.sanitizeDetectedItem({
    name: "Unknown sauce",
    estimatedPortion: "1 serving",
    quantityGrams: -10,
    confidence: "medium",
    calories: -50,
    proteinGrams: -2,
    carbsGrams: -3,
    fatGrams: -1
  });

  assert.equal(item.quantityGrams, 0);
  assert.equal(item.calories, 0);
  assert.equal(item.proteinGrams, 0);
  assert.equal(item.carbsGrams, 0);
  assert.equal(item.fatGrams, 0);
});

test("totals are recalculated server-side", async () => {
  const repository = new MockRepository();
  const payload: OpenAIFoodAnalysisResult = {
    detectedItems: [
      {
        name: "Rice",
        estimatedPortion: "120g",
        quantityGrams: 120,
        confidence: "medium",
        calories: 156,
        proteinGrams: 3.2,
        carbsGrams: 33.6,
        fatGrams: 0.4
      },
      {
        name: "Salad",
        estimatedPortion: "80g",
        quantityGrams: 80,
        confidence: "low",
        calories: 16,
        proteinGrams: 1,
        carbsGrams: 2.9,
        fatGrams: 0.2
      }
    ],
    totalCalories: 999,
    totalProteinGrams: 999,
    totalCarbsGrams: 999,
    totalFatGrams: 999,
    confidence: "high",
    notes: []
  };
  const service = new OpenAIFoodVisionService(
    repository as never,
    new StubResponsesClient(payload) as never
  );

  const analysis = await service.analyzeMealImage({
    userId: "demo-user",
    fileBuffer: Buffer.from("fake"),
    mimeType: "image/jpeg",
    filename: "meal.jpg"
  });

  assert.equal(analysis.totalCalories, 172);
  assert.equal(analysis.totalProteinGrams, 4.2);
  assert.equal(analysis.totalCarbsGrams, 36.5);
  assert.equal(analysis.totalFatGrams, 0.6);
  assert.equal(analysis.confidence, "low");
});

test("non-food image returns empty detected items", async () => {
  const repository = new MockRepository();
  const service = new OpenAIFoodVisionService(
    repository as never,
    new StubResponsesClient({
      detectedItems: [],
      totalCalories: 0,
      totalProteinGrams: 0,
      totalCarbsGrams: 0,
      totalFatGrams: 0,
      confidence: "low",
      notes: []
    }) as never
  );

  const analysis = await service.analyzeMealImage({
    userId: "demo-user",
    fileBuffer: Buffer.from("fake"),
    mimeType: "image/jpeg",
    filename: "not-food.jpg"
  });

  assert.deepEqual(analysis.detectedItems, []);
  assert.equal(analysis.confidence, "low");
  assert.ok(analysis.notes[0]?.includes("could not clearly identify food"));
});
