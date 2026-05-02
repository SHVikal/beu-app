import { Router } from "express";
import { DietRecommendationController } from "../controllers/dietRecommendationController.js";
import { validateBody } from "../middleware/validate.js";
import { recommendationRequestSchema } from "../validation/schemas.js";

const router = Router();
const controller = new DietRecommendationController();

router.post("/", validateBody(recommendationRequestSchema), controller.create);

export { router as dietRecommendationRoutes };
