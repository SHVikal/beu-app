import { Router } from "express";
import { AppStateController } from "../controllers/appStateController.js";

const router = Router();
const controller = new AppStateController();

router.get("/:userId", controller.get);
router.put("/:userId", controller.save);

export { router as appStateRoutes };
