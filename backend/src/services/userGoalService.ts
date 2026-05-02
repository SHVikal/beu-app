import { UserGoalRepository } from "../repositories/userGoalRepository.js";
import type { UserGoal } from "../types/health.js";

export class UserGoalService {
  constructor(private readonly repository = new UserGoalRepository()) {}

  save(goal: UserGoal): UserGoal {
    return this.repository.save(goal);
  }

  getByUserId(userId: string): UserGoal | null {
    return this.repository.getByUserId(userId);
  }
}
