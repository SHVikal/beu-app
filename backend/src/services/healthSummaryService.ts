import { HealthSummaryRepository } from "../repositories/healthSummaryRepository.js";
import type { HealthSummary } from "../types/health.js";

export class HealthSummaryService {
  constructor(private readonly repository = new HealthSummaryRepository()) {}

  save(summary: HealthSummary): HealthSummary {
    return this.repository.save(summary);
  }

  getDaily(userId: string, date: string): HealthSummary | null {
    return this.repository.getByUserAndDate(userId, date);
  }

  getRange(userId: string, days: number): HealthSummary[] {
    return this.repository.listByUser(userId, days);
  }
}
