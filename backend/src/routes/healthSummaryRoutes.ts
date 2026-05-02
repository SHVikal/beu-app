import { Router } from "express";
import { HealthSummaryController } from "../controllers/healthSummaryController.js";
import { validateBody, validateQuery } from "../middleware/validate.js";
import { healthSummarySchema, rangeQuerySchema } from "../validation/schemas.js";

const router = Router();
const controller = new HealthSummaryController();

router.post("/", validateBody(healthSummarySchema), controller.create);
router.get("/:userId/:date", controller.getDaily);
router.get("/:userId", validateQuery(rangeQuerySchema), controller.getRange);

export { router as healthSummaryRoutes };
