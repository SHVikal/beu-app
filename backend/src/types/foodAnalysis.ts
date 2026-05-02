import type { AnalysisConfidence, DetectedFoodItem, FoodAnalysisInputType, FoodImageAnalysis, MealType } from "./health.js";

export const FOOD_ANALYSIS_ERROR_CODES = {
  missingImage: "MISSING_IMAGE",
  missingDescription: "MISSING_DESCRIPTION",
  invalidImageType: "INVALID_IMAGE_TYPE",
  imageTooLarge: "IMAGE_TOO_LARGE",
  openAIUnavailable: "OPENAI_UNAVAILABLE",
  imageAnalysisFailed: "IMAGE_ANALYSIS_FAILED",
  textAnalysisFailed: "TEXT_ANALYSIS_FAILED"
} as const;

export type FoodAnalysisErrorCode = typeof FOOD_ANALYSIS_ERROR_CODES[keyof typeof FOOD_ANALYSIS_ERROR_CODES];

export interface OpenAIFoodDetectedItem {
  name: string;
  estimatedPortion: string;
  quantityGrams: number;
  confidence: AnalysisConfidence;
  calories: number;
  proteinGrams: number;
  carbsGrams: number;
  fatGrams: number;
}

export interface OpenAIFoodAnalysisResult {
  detectedItems: OpenAIFoodDetectedItem[];
  totalCalories: number;
  totalProteinGrams: number;
  totalCarbsGrams: number;
  totalFatGrams: number;
  confidence: AnalysisConfidence;
  notes: string[];
}

export interface FoodTextAnalysisInput {
  userId: string;
  description: string;
  mealType: MealType | "unknown";
  dietPreference: "indian_vegetarian" | "vegetarian" | "vegan" | "no_preference";
}

export interface FoodImageUploadInput {
  userId: string;
  fileBuffer: Buffer;
  mimeType: string;
  filename: string;
}

export interface FoodImageAnalysisResponse extends Omit<FoodImageAnalysis, "id"> {
  analysisId: string;
  detectedItems: DetectedFoodItem[];
  notes: string[];
}

export interface PersistedFoodAnalysisInput {
  userId: string;
  inputType: FoodAnalysisInputType;
  originalDescription?: string | null;
  imageLocalPath?: string | null;
  imageRemoteUrl?: string | null;
  detectedItems: DetectedFoodItem[];
  totalCalories: number;
  totalProteinGrams: number;
  totalCarbsGrams: number;
  totalFatGrams: number;
  confidence: AnalysisConfidence;
  notes: string[];
  createdAt?: string;
}

export interface FoodAnalysisFailureResponse {
  error: true;
  code: FoodAnalysisErrorCode;
  message: string;
}
