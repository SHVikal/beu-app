import { Router } from "express";
import { PlanController } from "../controllers/planController.js";
import { validateBody } from "../middleware/validate.js";
import { planMealLogSchema, waterLogSchema } from "../validation/schemas.js";

const router = Router();
const controller = new PlanController();

router.get("/plan/:userId/today", controller.getTodayPlan);
router.get("/plan/:userId/week", controller.getWeeklyPlan);
router.post("/plan/log-water", validateBody(waterLogSchema), controller.logWater);
router.post("/plan/log-meal", validateBody(planMealLogSchema), controller.logMeal);
router.get("/insights/:userId/week", controller.getWeeklyInsights);

export { router as planRoutes };
