import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import { env } from "../config/env.js";

const resolvedDbPath = path.resolve(process.cwd(), env.dbPath);
fs.mkdirSync(path.dirname(resolvedDbPath), { recursive: true });

export const db = new Database(resolvedDbPath);
db.pragma("journal_mode = WAL");

const schemaPath = path.resolve(process.cwd(), "src/db/schema.sql");
const schema = fs.readFileSync(schemaPath, "utf-8");
db.exec(schema);

// Keep local MVP databases forward-compatible as new columns are introduced.
const analysisColumns = db.prepare("PRAGMA table_info(food_image_analyses)").all() as Array<{ name: string }>;
if (!analysisColumns.some((column) => column.name === "notes_json")) {
  db.exec("ALTER TABLE food_image_analyses ADD COLUMN notes_json TEXT NOT NULL DEFAULT '[]'");
}
if (!analysisColumns.some((column) => column.name === "input_type")) {
  db.exec("ALTER TABLE food_image_analyses ADD COLUMN input_type TEXT NOT NULL DEFAULT 'image'");
}
if (!analysisColumns.some((column) => column.name === "original_description")) {
  db.exec("ALTER TABLE food_image_analyses ADD COLUMN original_description TEXT");
}

const healthSummaryColumns = db.prepare("PRAGMA table_info(health_summaries)").all() as Array<{ name: string }>;
if (!healthSummaryColumns.some((column) => column.name === "basal_energy_kcal")) {
  db.exec("ALTER TABLE health_summaries ADD COLUMN basal_energy_kcal REAL");
}
if (!healthSummaryColumns.some((column) => column.name === "total_energy_burned_kcal")) {
  db.exec("ALTER TABLE health_summaries ADD COLUMN total_energy_burned_kcal REAL");
}
if (!healthSummaryColumns.some((column) => column.name === "estimated_total_burn_kcal")) {
  db.exec("ALTER TABLE health_summaries ADD COLUMN estimated_total_burn_kcal REAL NOT NULL DEFAULT 0");
}

const mealLogColumns = db.prepare("PRAGMA table_info(meal_logs)").all() as Array<{ name: string }>;
if (!mealLogColumns.some((column) => column.name === "logged_at")) {
  db.exec("ALTER TABLE meal_logs ADD COLUMN logged_at TEXT");
  db.exec("UPDATE meal_logs SET logged_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE logged_at IS NULL");
}
if (!mealLogColumns.some((column) => column.name === "source")) {
  db.exec("ALTER TABLE meal_logs ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'");
}
if (!mealLogColumns.some((column) => column.name === "original_input")) {
  db.exec("ALTER TABLE meal_logs ADD COLUMN original_input TEXT");
}
