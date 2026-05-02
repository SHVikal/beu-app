# API Spec

Base URL: `http://localhost:4000`

## `POST /api/health-summary`
Upserts one normalized daily health summary.

Request:
```json
{
  "userId": "demo-user",
  "date": "2026-04-26",
  "steps": 8123,
  "activeEnergyKcal": 512,
  "workoutCount": 1,
  "workoutMinutes": 38,
  "workoutEnergyKcal": 275,
  "sleepHours": 6.9,
  "restingHeartRateBpm": 58,
  "hrvMs": 44,
  "weightKg": 78.4,
  "heightCm": 178
}
```

Response:
```json
{
  "userId": "demo-user",
  "date": "2026-04-26",
  "steps": 8123,
  "activeEnergyKcal": 512,
  "workoutCount": 1,
  "workoutMinutes": 38,
  "workoutEnergyKcal": 275,
  "sleepHours": 6.9,
  "restingHeartRateBpm": 58,
  "hrvMs": 44,
  "weightKg": 78.4,
  "heightCm": 178,
  "createdAt": "2026-04-26 08:00:00",
  "updatedAt": "2026-04-26 08:00:00"
}
```

## `GET /api/health-summary/:userId/:date`
Gets one daily summary.

Example:
`GET /api/health-summary/demo-user/2026-04-26`

## `GET /api/health-summary/:userId?days=7`
Gets a date-ordered range of summaries.

Response:
```json
{
  "userId": "demo-user",
  "days": 7,
  "summaries": []
}
```

## `POST /api/user-goal`
Creates or updates a goal.

Request:
```json
{
  "userId": "demo-user",
  "goal": "fat_loss",
  "notes": "Prefer simple workday meals."
}
```

## `GET /api/user-goal/:userId`
Gets one user goal.

## `POST /api/diet-recommendation`
Returns a deterministic recommendation.

Request:
```json
{
  "userId": "demo-user",
  "date": "2026-04-26"
}
```

Response:
```json
{
  "summary": "For 2026-04-26, you logged 7600 steps and 530 active kcal. Sleep was 6.2 hours and workouts totaled 32 minutes. Recommendation is tuned for a fat loss goal.",
  "suggestedCalorieDirection": "Avoid aggressive calorie restriction today. Favor steady, balanced intake.",
  "proteinGuidance": "Keep protein high and steady to support fullness and lean mass.",
  "carbGuidance": "Activity is above your 7-day average, so include slightly more carbs around active periods for energy and recovery.",
  "hydrationGuidance": "Drink water consistently through the day and include electrolytes after long or sweaty sessions.",
  "mealSuggestions": [
    "Greek yogurt with berries and nuts",
    "Chicken, rice, and roasted vegetables"
  ],
  "recoveryNote": "Because you trained recently, prioritize protein, fluids, and a meal or snack within a few hours of exercise.",
  "safetyNote": "This wellness guidance is informational only. It does not diagnose medical conditions or prescribe treatment. Consult a qualified healthcare professional for medical conditions, eating disorders, pregnancy, diabetes, or other special health needs.",
  "signals": [
    "Recent workout detected",
    "Sleep below 6.5 hours",
    "Goal: fat loss"
  ]
}
```

## Validation Notes
- `date` must be `YYYY-MM-DD`
- `days` supports `1...30`
- numeric fields must be non-negative

## Sample Requests
See [backend/scripts/example-requests.http](/Users/avikal/Documents/New%20project/backend/scripts/example-requests.http).
