CREATE TABLE IF NOT EXISTS health_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  steps INTEGER NOT NULL,
  active_energy_kcal REAL NOT NULL,
  basal_energy_kcal REAL,
  workout_count INTEGER NOT NULL,
  workout_minutes REAL NOT NULL,
  workout_energy_kcal REAL NOT NULL,
  total_energy_burned_kcal REAL,
  estimated_total_burn_kcal REAL NOT NULL DEFAULT 0,
  sleep_hours REAL NOT NULL,
  resting_heart_rate_bpm REAL,
  hrv_ms REAL,
  weight_kg REAL,
  height_cm REAL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, date)
);

CREATE TABLE IF NOT EXISTS user_goals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL UNIQUE,
  goal TEXT NOT NULL CHECK(goal IN ('fat_loss', 'muscle_gain', 'maintenance', 'general_wellness')),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_nutrition_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL UNIQUE,
  age INTEGER,
  sex TEXT CHECK(sex IN ('male', 'female', 'prefer_not_to_say')),
  height_cm REAL NOT NULL,
  current_weight_kg REAL NOT NULL,
  target_weight_kg REAL,
  goal_type TEXT NOT NULL CHECK(goal_type IN ('lose_weight', 'maintain_weight', 'gain_muscle', 'general_wellness')),
  daily_calorie_target INTEGER NOT NULL,
  daily_protein_target_grams INTEGER NOT NULL,
  daily_carb_target_grams INTEGER,
  daily_fat_target_grams INTEGER,
  target_timeline TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS food_image_analyses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  input_type TEXT NOT NULL DEFAULT 'image' CHECK(input_type IN ('image', 'text')),
  original_description TEXT,
  image_local_path TEXT,
  image_remote_url TEXT,
  detected_items_json TEXT NOT NULL,
  total_calories INTEGER NOT NULL,
  total_protein_grams REAL NOT NULL,
  total_carbs_grams REAL NOT NULL,
  total_fat_grams REAL NOT NULL,
  confidence TEXT NOT NULL CHECK(confidence IN ('high', 'medium', 'low')),
  notes_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS meal_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  meal_type TEXT NOT NULL CHECK(meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  logged_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('photo', 'text', 'library', 'manual')),
  original_input TEXT,
  image_local_path TEXT,
  items_json TEXT NOT NULL,
  total_calories INTEGER NOT NULL,
  total_protein_grams REAL NOT NULL,
  total_carbs_grams REAL NOT NULL,
  total_fat_grams REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_meal_logs_user_date ON meal_logs(user_id, date);

CREATE TABLE IF NOT EXISTS water_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  litres REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_water_logs_user_date ON water_logs(user_id, date);

CREATE TABLE IF NOT EXISTS supplements (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT NOT NULL CHECK(frequency IN ('daily', 'weekly', 'as_needed')),
  time_of_day TEXT CHECK(time_of_day IN ('morning', 'afternoon', 'evening', 'with_meal', 'before_bed')),
  notes TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS health_conditions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  condition_type TEXT NOT NULL CHECK(condition_type IN (
    'pcos', 'diabetes', 'thyroid', 'hypertension', 'anemia', 'cholesterol',
    'pregnancy', 'eating_disorder_history', 'other', 'prefer_not_to_say'
  )),
  custom_name TEXT,
  notes TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_supplements_user ON supplements(user_id);
CREATE INDEX IF NOT EXISTS idx_conditions_user ON health_conditions(user_id);
