import { db } from "../db/database.js";
import type { UserGoal } from "../types/health.js";

type UserGoalRow = {
  user_id: string;
  goal: UserGoal["goal"];
  notes: string | null;
  created_at: string;
  updated_at: string;
};

function toModel(row: UserGoalRow): UserGoal {
  return {
    userId: row.user_id,
    goal: row.goal,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export class UserGoalRepository {
  save(goal: UserGoal): UserGoal {
    const payload = {
      ...goal,
      notes: goal.notes ?? null
    };

    db.prepare(`
      INSERT INTO user_goals (user_id, goal, notes, updated_at)
      VALUES (@userId, @goal, @notes, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id) DO UPDATE SET
        goal = excluded.goal,
        notes = excluded.notes,
        updated_at = CURRENT_TIMESTAMP
    `).run(payload);

    const stored = this.getByUserId(goal.userId);
    if (!stored) {
      throw new Error("Failed to persist user goal.");
    }
    return stored;
  }

  getByUserId(userId: string): UserGoal | null {
    const row = db
      .prepare(`SELECT * FROM user_goals WHERE user_id = ?`)
      .get(userId) as UserGoalRow | undefined;

    return row ? toModel(row) : null;
  }
}
