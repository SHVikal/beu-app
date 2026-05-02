import type {
  DailyEnergyBalance,
  PersonalizationContext,
  StrengthTrainingPlan
} from "./actionPlanTypes.js";

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export class ActivityTargetService {
  build(context: PersonalizationContext, energyBalance: DailyEnergyBalance): {
    steps: number;
    cardioMinutes: number;
    strengthTraining: StrengthTrainingPlan;
    explanation: string[];
  } {
    const goal = context.profile?.goalType ?? "general_wellness";
    const readiness = context.readiness.status ?? "moderate";
    const sevenDayAvgSteps = context.healthData.sevenDayAvgSteps;
    const strengthSessions = context.healthData.strengthSessionsLast7Days ?? 0;

    const baseSteps =
      goal === "fat_loss" ? 8000 :
        goal === "muscle_gain" ? 7000 :
          goal === "maintain" ? 7500 : 7000;

    let stepsTarget = baseSteps;
    if (sevenDayAvgSteps !== null && Number.isFinite(sevenDayAvgSteps)) {
      if (sevenDayAvgSteps < baseSteps) {
        stepsTarget = Math.min(baseSteps, Math.round(sevenDayAvgSteps + 1000));
      } else {
        stepsTarget = Math.min(10000, Math.round(sevenDayAvgSteps + 500));
      }
    }

    if (readiness === "low") {
      stepsTarget = Math.round(stepsTarget * 0.85);
    } else if (readiness === "high" && (goal === "fat_loss" || goal === "general_wellness")) {
      stepsTarget = Math.round(stepsTarget * 1.05);
    }

    if (energyBalance.remainingBurnTarget <= 0) {
      stepsTarget = Math.max(context.healthData.todaySteps ?? 0, Math.round(stepsTarget * 0.9));
    }

    let strengthTraining: StrengthTrainingPlan;
    if (readiness === "low") {
      strengthTraining = {
        recommendation: "rest",
        durationMinutes: 20,
        intensity: "light",
        focus: "recovery"
      };
    } else if (goal === "muscle_gain") {
      strengthTraining = strengthSessions < 3
        ? {
            recommendation: "required",
            durationMinutes: 45,
            intensity: readiness === "high" ? "high" : "moderate",
            focus: "full_body"
          }
        : {
            recommendation: "optional",
            durationMinutes: 30,
            intensity: "moderate",
            focus: "upper_body"
          };
    } else if (goal === "fat_loss") {
      const isBehind = strengthSessions < 2;
      strengthTraining = isBehind
        ? {
            recommendation: "required",
            durationMinutes: 30,
            intensity: readiness === "high" ? "moderate" : "light",
            focus: "full_body"
          }
        : {
            recommendation: "optional",
            durationMinutes: 25,
            intensity: "moderate",
            focus: "mobility"
          };
    } else {
      strengthTraining = strengthSessions < 2
        ? {
            recommendation: "optional",
            durationMinutes: 30,
            intensity: readiness === "high" ? "moderate" : "light",
            focus: "full_body"
          }
        : {
            recommendation: "optional",
            durationMinutes: 20,
            intensity: "light",
            focus: "mobility"
          };
    }

    let cardioMinutes =
      goal === "fat_loss" ? 25 :
        goal === "muscle_gain" ? 12 :
          goal === "maintain" ? 20 : 20;

    if (readiness === "low") {
      cardioMinutes = 15;
    } else if ((context.healthData.todaySteps ?? 0) < stepsTarget * 0.4) {
      cardioMinutes = Math.max(cardioMinutes, 20);
    }

    if (goal === "muscle_gain" && energyBalance.workoutEnergyBurned > 250) {
      cardioMinutes = Math.min(cardioMinutes, 12);
    }
    if (energyBalance.remainingBurnTarget <= 0) {
      cardioMinutes = Math.max(10, Math.min(cardioMinutes, 15));
    }

    return {
      steps: clamp(stepsTarget, 5000, 10000),
      cardioMinutes,
      strengthTraining,
      explanation: [
        "Your step target is based on your recent 7-day average and current goal.",
        energyBalance.remainingBurnTarget <= 0
          ? "Today's burn target is already met, so extra cardio pressure stays low."
          : "Burn progress shapes how strongly BeU pushes steps and cardio today.",
        readiness === "low"
          ? "Today's activity is lighter because readiness is low."
          : "Today's activity assumes a normal training day unless recovery looks low."
      ]
    };
  }
}
