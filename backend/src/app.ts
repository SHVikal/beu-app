import cors from "cors";
import express from "express";
import { healthSummaryRoutes } from "./routes/healthSummaryRoutes.js";
import { userGoalRoutes } from "./routes/userGoalRoutes.js";
import { dietRecommendationRoutes } from "./routes/dietRecommendationRoutes.js";
import { nutritionRoutes } from "./routes/nutritionRoutes.js";
import { foodRoutes } from "./routes/foodRoutes.js";
import { planRoutes } from "./routes/planRoutes.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { env } from "./config/env.js";

export function createApp() {
  const app = express();

  app.use(cors(corsOptions()));
  app.use(express.json({ limit: "2mb" }));
  app.use(express.urlencoded({ extended: true, limit: "2mb" }));

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "beu-backend",
      timestamp: new Date().toISOString()
    });
  });
  app.get("/api/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "beu-backend",
      timestamp: new Date().toISOString()
    });
  });

  app.use("/api/health-summary", healthSummaryRoutes);
  app.use("/api/user-goal", userGoalRoutes);
  app.use("/api/diet-recommendation", dietRecommendationRoutes);
  app.use("/api", nutritionRoutes);
  app.use("/api", foodRoutes);
  app.use("/api", planRoutes);

  app.use(errorHandler);

  return app;
}

type CorsDecisionCallback = (error: Error | null, allow?: boolean) => void;

function corsOptions() {
  const raw = env.allowedOrigins.trim();
  if (raw === "*" || raw.length == 0) {
    return { origin: true };
  }

  const allowed = raw
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  return {
    origin(origin: string | undefined, callback: CorsDecisionCallback) {
      if (!origin || allowed.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error("Origin not allowed by CORS"));
    }
  };
}
