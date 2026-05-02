import fs from "node:fs";
import path from "node:path";

loadDotEnv();

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  host: process.env.HOST ?? "0.0.0.0",
  port: Number.parseInt(process.env.PORT ?? "3000", 10),
  dbPath: process.env.DATABASE_URL ?? process.env.DB_PATH ?? "./data/health-diet-coach.sqlite",
  openAIAPIKey: process.env.OPENAI_API_KEY ?? "",
  openAIVisionModel: process.env.OPENAI_VISION_MODEL ?? "gpt-4o-mini",
  openAITextModel: process.env.OPENAI_TEXT_MODEL ?? "gpt-4o-mini",
  allowedOrigins: process.env.ALLOWED_ORIGINS ?? "*"
};

function loadDotEnv() {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) {
    return;
  }

  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const rawValue = trimmed.slice(separatorIndex + 1).trim();
    if (!key || process.env[key] !== undefined) {
      continue;
    }

    process.env[key] = stripWrappingQuotes(rawValue);
  }
}

function stripWrappingQuotes(value: string): string {
  if (
    (value.startsWith("\"") && value.endsWith("\"")) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}
