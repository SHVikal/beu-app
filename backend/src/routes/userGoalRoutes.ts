import { Router } from "express";
import { UserGoalController } from "../controllers/userGoalController.js";
import { validateBody } from "../middleware/validate.js";
import { userGoalSchema } from "../validation/schemas.js";

const router = Router();
const controller = new UserGoalController();

router.post("/", validateBody(userGoalSchema), controller.create);
router.get("/:userId", controller.getByUserId);

export { router as userGoalRoutes };
