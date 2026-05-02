# BeU MVP

This workspace now includes a new MVP build for `BeU` in the requested folders:

- [ios/HealthDietCoach](/Users/avikal/Documents/New%20project/ios/HealthDietCoach)
- [backend](/Users/avikal/Documents/New%20project/backend)
- [mcp-server-stub](/Users/avikal/Documents/New%20project/mcp-server-stub)
- [docs](/Users/avikal/Documents/New%20project/docs)

## What It Does
- Reads Apple Health / Apple Watch data through HealthKit
- Aggregates raw samples into normalized daily summaries
- Stores summaries and user goals in a Node.js + Express + TypeScript backend
- Generates deterministic diet recommendations with safe wellness wording
- Keeps the backend structured so MCP tools can be added later
- Adds nutrition onboarding, meal photo logging, meal history, and weekly nutrition summary
- Adds profile-level supplement tracking and health history tracking for wording-only daily plan personalization
- Uses backend-only OpenAI vision analysis for meal photos with user confirmation before logging

## Project Structure
```text
backend/            Express + TypeScript + SQLite API
ios/HealthDietCoach SwiftUI iOS app and Xcode project
mcp-server-stub/    MCP planning docs and tool definitions
docs/               PRD, architecture, API, privacy and safety
```

## Backend Local Run
```bash
cd "/Users/avikal/Documents/New project/backend"
cp .env.example .env
npm install
npm run seed
npm run dev
```

Set `OPENAI_API_KEY` in `backend/.env` before using meal photo analysis. The default vision model is `gpt-5.4-mini`, configurable through `OPENAI_VISION_MODEL`.

The API starts on the configured port in `.env`. If you use the provided example file as-is, it starts on `http://localhost:3000`.

## iOS Local Run
1. Open [HealthDietCoach.xcodeproj](/Users/avikal/Documents/New%20project/ios/HealthDietCoach/HealthDietCoach.xcodeproj).
2. In Xcode, select the `HealthDietCoach` target.
3. Set your own Bundle Identifier and Apple Team under Signing & Capabilities.
4. Add the `HealthKit` capability if Xcode has not already preserved it from the entitlements file.
5. If you run on a physical iPhone, set `BackendBaseURL` to your Mac's LAN IP and the backend port from `.env`.
6. Run on a physical iPhone for real HealthKit testing.
7. Meal photo capture requires a physical iPhone. On simulator, use upload from gallery.

The app display name on device is now `BeU`.

## Key Docs
- [PRD.md](/Users/avikal/Documents/New%20project/docs/PRD.md)
- [ARCHITECTURE.md](/Users/avikal/Documents/New%20project/docs/ARCHITECTURE.md)
- [API_SPEC.md](/Users/avikal/Documents/New%20project/docs/API_SPEC.md)
- [PRIVACY_AND_SAFETY.md](/Users/avikal/Documents/New%20project/docs/PRIVACY_AND_SAFETY.md)
- [APP_ICON_OPTIONS.md](/Users/avikal/Documents/New%20project/docs/APP_ICON_OPTIONS.md)
- [FOOD_IMAGE_ANALYSIS.md](/Users/avikal/Documents/New%20project/docs/FOOD_IMAGE_ANALYSIS.md)
- [FEATURES.md](/Users/avikal/Documents/New%20project/docs/FEATURES.md)

## Important MVP Notes
- The backend is fully implemented in code, but I could not install Node packages in this sandbox because `npm` is unavailable here.
- HealthKit aggregation is implemented in the app, but real permission and data testing requires a physical iPhone with Health data.
- The recommendation engine is deterministic business logic only. No paid APIs or external data sources are required.
