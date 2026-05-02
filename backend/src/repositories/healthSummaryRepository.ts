import { db } from "../db/database.js";
import type { HealthSummary } from "../types/health.js";

type HealthSummaryRow = {
  user_id: string;
  date: string;
  steps: number;
  active_energy_kcal: number;
  basal_energy_kcal: number | null;
  workout_count: number;
  workout_minutes: number;
  workout_energy_kcal: number;
  total_energy_burned_kcal: number | null;
  estimated_total_burn_kcal: number;
  sleep_hours: number;
  resting_heart_rate_bpm: number | null;
  hrv_ms: number | null;
  weight_kg: number | null;
  height_cm: number | null;
  created_at: string;
  updated_at: string;
};

function toModel(row: HealthSummaryRow): HealthSummary {
  return {
    userId: row.user_id,
    date: row.date,
    steps: row.steps,
    activeEnergyKcal: row.active_energy_kcal,
    basalEnergyKcal: row.basal_energy_kcal,
    workoutCount: row.workout_count,
    workoutMinutes: row.workout_minutes,
    workoutEnergyKcal: row.workout_energy_kcal,
    totalEnergyBurnedKcal: row.total_energy_burned_kcal,
    estimatedTotalBurnKcal: row.estimated_total_burn_kcal,
    sleepHours: row.sleep_hours,
    restingHeartRateBpm: row.resting_heart_rate_bpm,
    hrvMs: row.hrv_ms,
    weightKg: row.weight_kg,
    heightCm: row.height_cm,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export class HealthSummaryRepository {
  save(summary: HealthSummary): HealthSummary {
    const payload = {
      ...summary,
      basalEnergyKcal: summary.basalEnergyKcal ?? null,
      totalEnergyBurnedKcal: summary.totalEnergyBurnedKcal ?? null,
      restingHeartRateBpm: summary.restingHeartRateBpm ?? null,
      hrvMs: summary.hrvMs ?? null,
      weightKg: summary.weightKg ?? null,
      heightCm: summary.heightCm ?? null
    };

    const statement = db.prepare(`
      INSERT INTO health_summaries (
        user_id,
        date,
        steps,
        active_energy_kcal,
        basal_energy_kcal,
        workout_count,
        workout_minutes,
        workout_energy_kcal,
        total_energy_burned_kcal,
        estimated_total_burn_kcal,
        sleep_hours,
        resting_heart_rate_bpm,
        hrv_ms,
        weight_kg,
        height_cm,
        updated_at
      ) VALUES (
        @userId,
        @date,
        @steps,
        @activeEnergyKcal,
        @basalEnergyKcal,
        @workoutCount,
        @workoutMinutes,
        @workoutEnergyKcal,
        @totalEnergyBurnedKcal,
        @estimatedTotalBurnKcal,
        @sleepHours,
        @restingHeartRateBpm,
        @hrvMs,
        @weightKg,
        @heightCm,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT(user_id, date) DO UPDATE SET
        steps = excluded.steps,
        active_energy_kcal = excluded.active_energy_kcal,
        basal_energy_kcal = excluded.basal_energy_kcal,
        workout_count = excluded.workout_count,
        workout_minutes = excluded.workout_minutes,
        workout_energy_kcal = excluded.workout_energy_kcal,
        total_energy_burned_kcal = excluded.total_energy_burned_kcal,
        estimated_total_burn_kcal = excluded.estimated_total_burn_kcal,
        sleep_hours = excluded.sleep_hours,
        resting_heart_rate_bpm = excluded.resting_heart_rate_bpm,
        hrv_ms = excluded.hrv_ms,
        weight_kg = excluded.weight_kg,
        height_cm = excluded.height_cm,
        updated_at = CURRENT_TIMESTAMP
    `);

    statement.run(payload);
    const stored = this.getByUserAndDate(summary.userId, summary.date);
    if (!stored) {
      throw new Error("Failed to persist health summary.");
    }
    return stored;
  }

  getByUserAndDate(userId: string, date: string): HealthSummary | null {
    const row = db
      .prepare(
        `SELECT * FROM health_summaries WHERE user_id = ? AND date = ?`
      )
      .get(userId, date) as HealthSummaryRow | undefined;

    return row ? toModel(row) : null;
  }

  listByUser(userId: string, days: number): HealthSummary[] {
    const rows = db
      .prepare(
        `SELECT * FROM health_summaries WHERE user_id = ? ORDER BY date DESC LIMIT ?`
      )
      .all(userId, days) as HealthSummaryRow[];

    return rows.map(toModel).reverse();
  }
}
