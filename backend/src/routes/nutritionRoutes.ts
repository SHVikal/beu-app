import { Router } from "express";
import { NutritionController } from "../controllers/nutritionController.js";
import { validateBody } from "../middleware/validate.js";
import {
  healthConditionSchema,
  mealLogSchema,
  nutritionProfileSchema,
  supplementSchema
} from "../validation/schemas.js";

const router = Router();
const controller = new NutritionController();

router.post("/nutrition-profile", validateBody(nutritionProfileSchema), controller.createProfile);
router.get("/nutrition-profile/:userId", controller.getProfile);
router.put("/nutrition-profile/:userId", validateBody(nutritionProfileSchema.omit({ userId: true })), controller.updateProfile);

router.post("/meal-log", validateBody(mealLogSchema), controller.saveMealLog);
router.get("/meal-log/:userId/:date", controller.getMealLogsForDate);
router.put("/meal-log/:mealLogId", validateBody(mealLogSchema.omit({ id: true })), controller.updateMealLog);
router.delete("/meal-log/:mealLogId", controller.deleteMealLog);

router.get("/nutrition-progress/:userId/:date", controller.getDailyProgress);
router.get("/weekly-nutrition-summary/:userId", controller.getWeeklySummary);

router.post("/supplements", validateBody(supplementSchema), controller.createSupplement);
router.get("/supplements/:userId", controller.getSupplements);
router.put("/supplements/:supplementId", validateBody(supplementSchema.omit({ id: true })), controller.updateSupplement);
router.delete("/supplements/:supplementId", controller.deleteSupplement);

router.post("/health-conditions", validateBody(healthConditionSchema), controller.createHealthCondition);
router.get("/health-conditions/:userId", controller.getHealthConditions);
router.put("/health-conditions/:conditionId", validateBody(healthConditionSchema.omit({ id: true })), controller.updateHealthCondition);
router.delete("/health-conditions/:conditionId", controller.deleteHealthCondition);

export { router as nutritionRoutes };
