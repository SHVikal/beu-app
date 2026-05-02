import "../db/database.js";
import { HealthSummaryService } from "../services/healthSummaryService.js";
import { UserGoalService } from "../services/userGoalService.js";
import { currentIsoDay, shiftIsoDay } from "../utils/date.js";

const summaryService = new HealthSummaryService();
const goalService = new UserGoalService();
const userId = "demo-user";
const today = currentIsoDay();

goalService.save({
  userId,
  goal: "fat_loss",
  notes: "Demo goal seeded for local MVP testing."
});

const samples = [
  { offset: -6, steps: 5800, active: 360, workouts: 0, minutes: 0, workoutEnergy: 0, sleep: 7.2, rhr: 60, hrv: 42 },
  { offset: -5, steps: 8100, active: 480, workouts: 1, minutes: 36, workoutEnergy: 260, sleep: 6.7, rhr: 58, hrv: 44 },
  { offset: -4, steps: 7200, active: 420, workouts: 0, minutes: 0, workoutEnergy: 0, sleep: 6.1, rhr: 61, hrv: 39 },
  { offset: -3, steps: 9100, active: 560, workouts: 1, minutes: 42, workoutEnergy: 300, sleep: 7.4, rhr: 57, hrv: 48 },
  { offset: -2, steps: 6400, active: 390, workouts: 0, minutes: 0, workoutEnergy: 0, sleep: 6.8, rhr: 60, hrv: 41 },
  { offset: -1, steps: 10500, active: 610, workouts: 1, minutes: 50, workoutEnergy: 340, sleep: 7.0, rhr: 56, hrv: 50 },
  { offset: 0, steps: 7600, active: 530, workouts: 1, minutes: 32, workoutEnergy: 220, sleep: 6.2, rhr: 59, hrv: 43 }
];

for (const sample of samples) {
  summaryService.save({
    userId,
    date: shiftIsoDay(today, sample.offset),
    steps: sample.steps,
    activeEnergyKcal: sample.active,
    basalEnergyKcal: 1540,
    workoutCount: sample.workouts,
    workoutMinutes: sample.minutes,
    workoutEnergyKcal: sample.workoutEnergy,
    totalEnergyBurnedKcal: 1540 + sample.active,
    estimatedTotalBurnKcal: 1540 + sample.active,
    sleepHours: sample.sleep,
    restingHeartRateBpm: sample.rhr,
    hrvMs: sample.hrv,
    weightKg: 78.4,
    heightCm: 178
  });
}

console.log(`Seeded demo data for ${userId}.`);
