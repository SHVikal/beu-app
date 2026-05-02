# Privacy and Safety

## Privacy
- The iOS app requests read-only HealthKit access for the MVP.
- The app aggregates raw HealthKit data on-device into daily summaries.
- The backend stores normalized daily summaries, not raw sample streams.
- MVP authentication uses a plain `userId` and must be replaced before production launch.
- If you run the app on a physical iPhone, the backend should be hosted on a trusted local network or secured environment.

## Safety
- Recommendations are wellness-oriented and deterministic.
- The app does not diagnose medical conditions.
- The app does not prescribe treatment.
- The app does not recommend supplement dosage, starting, stopping, or interaction changes.
- The UI and API both include safety wording encouraging professional care for:
  - medical conditions
  - eating disorders
  - pregnancy
  - diabetes
  - other special health needs

## Health history use
- Health history is optional and user-editable.
- BeU uses health history only to personalize wording and plan emphasis.
- Health history is not used to diagnose, treat, or replace clinical advice.
- Supplements entered by the user are used only for reminder phrasing inside the daily plan.

## Known MVP Constraints
- Recommendation logic is rule-based, not personalized clinical nutrition guidance.
- Sleep aggregation depends on available Apple Health sleep samples.
- Simulator HealthKit support is limited; real HealthKit testing should happen on-device.
