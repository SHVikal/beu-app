import { AppStateRepository } from "../repositories/appStateRepository.js";
import type { UserAppStateSnapshot } from "../types/appState.js";

export class AppStateService {
  private readonly repository = new AppStateRepository();

  save(snapshot: UserAppStateSnapshot): UserAppStateSnapshot {
    return this.repository.save(snapshot);
  }

  get(userId: string): UserAppStateSnapshot | null {
    return this.repository.get(userId);
  }
}
