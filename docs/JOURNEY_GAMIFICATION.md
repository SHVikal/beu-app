# BeU Journey Gamification

## Concept
- Travel Trail is a premium walking challenge built on Apple Health steps.
- The user selects one of five routes and walks it virtually over time.
- Journey progress, daily distance, points, and badges are all route-aware.

## Available routes
- `Dubai -> Berlin` — `4700 km`
- `Dubai -> Istanbul` — `3000 km`
- `Dubai -> Paris` — `5250 km`
- `Dubai -> Rome` — `4350 km`
- `Dubai -> London` — `5500 km`

## Distance formula
- Default step length: `0.75m`
- If height is available:
  - `stepLengthMeters = heightCm * 0.00415`
- Daily distance:
  - `steps * stepLengthMeters / 1000`

## Progress model
- `DailyJourneyLog`
  - keyed by `userId + challengeId + date`
  - stores steps, distance, and points for a single route on a single day
- `JourneyProgress`
  - stored separately per challenge
  - stores current totals, city progress, points, title, and level
- `JourneyAchievement`
  - computed per challenge for distance, city, streak, and step badges
- Selected route:
  - stored separately per user

## Route switching
- Switching routes does not wipe progress.
- Each route keeps its own:
  - daily logs
  - total distance
  - points
  - level
  - title
  - achievements

## Sync logic
- Journey sync uses the Apple Health summaries already loaded in the app.
- When a summary for a date changes, that route-day log is replaced.
- Total distance is recalculated from `DailyJourneyLog.distanceKm`.
- This prevents double counting.

## Points system
- Base: `1 point per 100 steps`
- Bonus: `+50` for hitting the daily step goal
- Bonus: `+100` when the user reaches a 7-day walking streak milestone
- Bonus: `+250` per newly unlocked city

## Levels and titles
- Level 1: `0` points — `City Starter`
- Level 2: `500` points — `Street Walker`
- Level 3: `1200` points — `Desert Voyager`
- Level 4: `2500` points — `Skyline Scout`
- Level 5: `4000` points — `Border Crosser`
- Level 6: `6500` points — `Nomad Navigator`
- Level 7: `9000` points — `Globe Trekker`
- Level 8: `12000` points — `Continental Explorer`
- Level 9: `16000` points — `Route Master`
- Level 10: `21000` points — `Berlin Finisher`

## Badge logic
- Distance badges:
  - `10 km`
  - `100 km`
  - `500 km`
  - `1000 km`
  - `2500 km`
- City badges:
  - one per milestone city beyond the starting city
- Streak badges:
  - `3-day`
  - `7-day`
  - `30-day`
- Step badges:
  - `10,000`
  - `15,000`
  - `20,000` steps in a day
- Completion badges:
  - first route completed
  - three routes completed
  - all five routes completed

## UX notes
- The active route is selectable from a bottom sheet.
- The hero card is the main progress surface.
- Current, next, and next-next stops are shown as postcard-style cards.
- Badges open into a dedicated sheet with filter states:
  - `All`
  - `Earned`
  - `Locked`

## Known limitations
- MVP persistence is local-only.
- Reinstalling the app resets Journey progress.
- Badges and progress are not synced to backend/cloud yet.
- The feature depends on Apple Health step availability.
