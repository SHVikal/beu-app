import { db } from "../db/database.js";
import type { UserAppStateSnapshot } from "../types/appState.js";

type AppStateRow = {
  user_id: string;
  payload_json: string;
  created_at: string;
  updated_at: string;
};

export class AppStateRepository {
  save(snapshot: UserAppStateSnapshot): UserAppStateSnapshot {
    db.prepare(`
      INSERT INTO user_app_state_snapshots (
        user_id, payload_json, updated_at
      ) VALUES (
        @userId, @payloadJson, CURRENT_TIMESTAMP
      )
      ON CONFLICT(user_id) DO UPDATE SET
        payload_json = excluded.payload_json,
        updated_at = CURRENT_TIMESTAMP
    `).run({
      userId: snapshot.userId,
      payloadJson: JSON.stringify(snapshot.payload ?? {})
    });

    const stored = this.get(snapshot.userId);
    if (!stored) {
      throw new Error("Failed to persist app state snapshot.");
    }
    return stored;
  }

  get(userId: string): UserAppStateSnapshot | null {
    const row = db.prepare(`
      SELECT * FROM user_app_state_snapshots WHERE user_id = ?
    `).get(userId) as AppStateRow | undefined;

    if (!row) {
      return null;
    }

    return {
      userId: row.user_id,
      payload: JSON.parse(row.payload_json),
      createdAt: normalizeTimestamp(row.created_at),
      updatedAt: normalizeTimestamp(row.updated_at)
    };
  }
}

function normalizeTimestamp(value: string): string {
  if (!value) {
    return value;
  }

  if (value.includes("T") && (value.endsWith("Z") || value.includes("+"))) {
    return value;
  }

  const normalized = value.replace(" ", "T");
  return normalized.endsWith("Z") ? normalized : `${normalized}Z`;
}
