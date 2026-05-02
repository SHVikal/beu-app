import { Router } from "express";
import multer from "multer";
import { FoodAnalysisController } from "../controllers/foodAnalysisController.js";
import { validateBody } from "../middleware/validate.js";
import { analysisItemsUpdateSchema, foodTextAnalysisRequestSchema } from "../validation/schemas.js";
import {
  allowedFoodImageMimeTypes,
  FoodAnalysisHttpError,
  maxFoodImageBytes
} from "../validators/foodAnalysisValidator.js";
import { FOOD_ANALYSIS_ERROR_CODES } from "../types/foodAnalysis.js";

const router = Router();
const controller = new FoodAnalysisController();
const requestsByKey = new Map<string, number[]>();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: maxFoodImageBytes
  },
  fileFilter: (_req, file, callback) => {
    if (!allowedFoodImageMimeTypes.has(file.mimetype)) {
      callback(new FoodAnalysisHttpError(
        415,
        FOOD_ANALYSIS_ERROR_CODES.invalidImageType,
        "Please upload a JPG, PNG, or HEIC food photo."
      ));
      return;
    }
    callback(null, true);
  }
});

router.post(
  "/food/analyze-image",
  applySimpleRateLimit,
  upload.single("image"),
  controller.analyzeImage.bind(controller)
);
router.post(
  "/food/analyze-text",
  applySimpleRateLimit,
  validateBody(foodTextAnalysisRequestSchema),
  controller.analyzeText.bind(controller)
);
router.put("/food/analysis/:analysisId/items", validateBody(analysisItemsUpdateSchema), controller.updateAnalysisItems.bind(controller));

export { router as foodRoutes };

function applySimpleRateLimit(req: { ip?: string; body: { userId?: string } }, _res: unknown, next: (error?: Error) => void) {
  const now = Date.now();
  const windowMs = 5 * 60 * 1000;
  const maxRequests = 12;
  const key = req.body?.userId || req.ip || "anonymous";
  const recent = (requestsByKey.get(key) ?? []).filter((timestamp) => now - timestamp < windowMs);
  if (recent.length >= maxRequests) {
    next(new FoodAnalysisHttpError(
      429,
      "RATE_LIMITED",
      "Too many meal analysis requests. Please wait a moment and try again."
    ));
    return;
  }
  recent.push(now);
  requestsByKey.set(key, recent);
  next();
}
