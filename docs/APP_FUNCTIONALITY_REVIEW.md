# BeU App Functionality Review

## 1. Executive Summary
BeU is currently a single-user, wellness-focused iOS app that combines onboarding, goal setup, Apple Health inputs, a daily wellness plan, meal logging, nutrition estimation, supplements, progress tracking, and a gamified walking journey. The app’s strongest product idea is: set a stable daily target framework once, then use daily health and meal data to guide the user with adaptive coaching, nutrition feedback, and gentle course correction.

The main user journey is:
- complete baseline onboarding
- set a goal
- optionally connect Apple Health
- view Home and Plan for daily guidance
- log meals and water
- watch counters, nudges, and adaptive suggestions update
- track weekly progress and Journey progress over time

The main gaps and risks are:
- the app uses a mix of local-only state and backend-backed state, and the active shell does not use the backend for everything the codebase supports
- missing Apple Health data can silently fall back to prototype/demo data, which is useful for demos but risky for trust
- there are signs of duplicate legacy flows in the repo, which increases the risk of inconsistent behavior across screens
- meal analysis is backend-dependent and still needs full real-device validation after recent changes
- several persistence models are local-only, so multi-device behavior and reinstall behavior are limited

## 2. App Navigation Overview

### Home
Purpose:
Shows the user’s daily wellness summary and key plan information.

Main actions:
- View readiness
- View daily targets
- View Apple Health status and current metrics
- Open the full Plan tab
- Open the Progress tab

Connected screens:
- Plan
- Progress

### Plan
Purpose:
Shows the user’s detailed daily plan, adaptive coaching, training guidance, meal ideas, supplement reminders, and plan explanation.

Main actions:
- Review intake and burn
- Review adaptive coach update
- Review water guidance
- Review training recommendations
- Review meal ideas
- Edit or delete a logged meal from meal sections
- Mark supplements taken or undo them

Connected screens:
- Log Meal sheet
- Meal edit flow

### Log Meal
Purpose:
Opens the meal logging sheet and related review flow.

Main actions:
- Take a meal photo
- Describe a meal in words
- Upload a meal image from library
- Log water
- Review previously logged meals
- Edit or delete meals

Connected screens:
- Describe meal
- Meal analysis loading
- Review detected items
- Estimated nutrition
- Success state

### Journey
Purpose:
Shows the Travel Trail walking challenge using Apple Health steps converted into virtual travel progress.

Main actions:
- Select a route challenge
- Review route progress
- Review current and next city
- Review mission, rewards, unlockables, and badges
- Open the badges sheet
- Re-sync Health if needed

Connected screens:
- Route selector sheet
- Badge sheet
- Badge detail sheet

### Progress
Purpose:
Shows a compact weekly progress summary.

Main actions:
- Review 7-day readiness trend
- Review weekly burn/eating trend
- Review consistency score

Connected screens:
- None directly in the active shell

### Profile
Purpose:
Shows baseline profile, goal, and connection status.

Main actions:
- Review baseline
- Re-open baseline setup
- Change goal
- View Apple Health/backend status

Connected screens:
- Onboarding/baseline review
- Goal setup

## 3. Full User Flows

### First-time onboarding

User goal:
Set up a personal baseline so the app can personalize daily guidance.

Steps:
1. Open app for the first time.
2. See welcome screen.
3. Enter body profile information.
4. Select health context items.
5. Add supplements if desired.
6. Review summary.
7. Confirm baseline.

Inputs used:
- Name
- Gender
- Age
- Height
- Weight
- Health conditions
- Health notes
- Supplements

Expected output:
- Baseline is saved.
- App advances to goal setup.

Current status:
- Working

Potential issues:
- Some headings still use decorative serif/italic styling, which may feel more brand-led than utility-led.
- Health conditions and supplements are part of the baseline flow rather than dedicated management screens in the active shell.

### Set/update goal

User goal:
Choose a fat loss, muscle gain, maintenance, or wellness goal.

Steps:
1. Enter goal setup after onboarding or from Profile.
2. Select goal type.
3. If relevant, set target weight.
4. Select a timeline.
5. Save.

Inputs used:
- Baseline body data
- Goal type
- Target weight
- Timeline

Expected output:
- Goal is saved.
- Daily calorie and protein targets are recalculated.
- App moves to main shell or refreshes current plan.

Current status:
- Working

Potential issues:
- Goal preview shows estimated calories/protein, but the app later layers adaptive recommendations on top, which may confuse users if not explained well.

### Apple Health sync

User goal:
Let the app use real health/activity data.

Steps:
1. App requests Health permissions.
2. If granted, Health data is fetched.
3. Home, Plan, Progress, and Journey update.

Inputs used:
- Steps
- Active energy
- Basal energy
- Workouts
- Sleep
- HRV
- Resting heart rate

Expected output:
- Real metrics appear across the app.
- Readiness and Journey update.

Current status:
- Partially working

Potential issues:
- If Health fetch fails, the app falls back to prototype/demo data rather than a strict failure state.
- This helps demos, but it can hide real sync problems from users and product reviewers.

### Generate readiness score

User goal:
Understand current recovery state.

Steps:
1. Health data is refreshed.
2. Readiness is calculated from sleep, HRV, resting heart rate, and yesterday activity load.
3. Readiness appears on Home and feeds the daily plan.

Inputs used:
- Sleep
- HRV
- Resting heart rate
- Yesterday activity load
- Recent history for normalization

Expected output:
- Score
- Status
- One-line message
- Contributing factors

Current status:
- Working

Potential issues:
- If key Health inputs are missing, the app can still produce a score using neutral/default logic.
- That is good for continuity, but users may not realize the score is partly estimated.

### View daily plan

User goal:
See what to focus on today.

Steps:
1. Open Home or Plan.
2. Review targets, adaptive coach update, training, water, meal guidance, and supplements.

Inputs used:
- Baseline
- Goal
- Health signals
- Readiness
- Meal logs
- Water progress
- Supplements and taken logs
- Historical performance

Expected output:
- Daily targets
- Adaptive coaching
- Meal ideas
- Activity guidance
- Supplement reminders

Current status:
- Working

Potential issues:
- The app has both stable targets and adaptive advice, which is a good approach, but the distinction may not yet be obvious to users.

### Log meal using text

User goal:
Describe a meal and turn it into reviewable nutrition items.

Steps:
1. Open Log Meal.
2. Tap “Describe in words”.
3. Enter meal description.
4. Select meal type.
5. Tap “Analyze meal”.
6. Wait for backend analysis.
7. Review detected items.
8. Confirm items.
9. Review estimated nutrition.
10. Log the meal.

Inputs used:
- Typed meal description
- Meal type
- Diet preference
- Backend meal analysis
- OpenAI via backend

Expected output:
- Parsed food items
- Macro estimate
- Logged meal
- Updated daily counters

Current status:
- Partially working

Potential issues:
- This flow has been changed multiple times recently and still needs device-level validation.
- The backend path is correct, but production confidence should come from real-device testing rather than code inspection alone.

### Log meal using photo

User goal:
Take or upload a food photo and get estimated food items/macros.

Steps:
1. Open Log Meal.
2. Tap “Take a photo” or “Choose from library”.
3. Provide image.
4. Wait for backend analysis.
5. Review detected items.
6. Confirm items.
7. Review estimated nutrition.
8. Log the meal.

Inputs used:
- Meal photo
- Backend meal analysis
- OpenAI via backend

Expected output:
- Detected items
- Estimated macros
- Logged meal

Current status:
- Partially working

Potential issues:
- The flow is backend-dependent and needs real-device validation for camera/gallery permissions and image upload behavior.

### Review detected food items

User goal:
Correct the meal before saving it.

Steps:
1. Review detected items from text or photo analysis.
2. Edit name, portion, grams, calories, protein, carbs, fat.
3. Add missing item if needed.
4. Remove incorrect item if needed.
5. Confirm items.

Inputs used:
- Backend analysis result
- Manual user edits

Expected output:
- A confirmed analysis object
- Recomputed totals

Current status:
- Working

Potential issues:
- The review screen still includes a per-item “Confirmed” toggle plus a global “Confirm items” button, which may feel redundant or confusing.

### Edit detected meal item

User goal:
Fix a single detected item before logging.

Steps:
1. Open review screen.
2. Change name, grams, portion, or macros.
3. Continue to estimate screen.

Inputs used:
- DetectedFoodItem fields

Expected output:
- Updated items
- Updated totals

Current status:
- Working

Potential issues:
- Because macros are directly editable, the app depends on the user not making unrealistic edits.

### Delete logged meal

User goal:
Remove a meal and update the rest of the day.

Steps:
1. Tap delete from meal list or meal card.
2. See confirmation dialog.
3. Confirm delete.
4. Meal is removed.
5. Daily counters refresh.

Inputs used:
- Existing meal log

Expected output:
- Meal disappears
- Calories/macros recalculate
- Plan updates

Current status:
- Partially working

Potential issues:
- This flow has had recent crash fixes and should be treated as high-priority for device regression testing.

### Update daily nutrition counters

User goal:
See daily calories and macros update after meal actions.

Steps:
1. Log, edit, or delete a meal.
2. App reloads local meal logs for the day.
3. Counters update on Home and Plan.

Inputs used:
- Meal logs
- Water progress
- Step count

Expected output:
- Updated calories, protein, carbs, fat, water, and meal count

Current status:
- Working

Potential issues:
- In the active shell, this is local-first rather than backend-first, so multi-device consistency is limited.

### Mark supplement as taken

User goal:
Track today’s supplement adherence.

Steps:
1. Open Plan.
2. Go to Supplement Reminder.
3. Tap “Mark taken”.
4. Status changes to Taken.
5. Tap “Undo” if needed.

Inputs used:
- Baseline supplement list
- Daily supplement intake logs

Expected output:
- Supplement status updates for today
- Status persists across app restarts for the same day

Current status:
- Working

Potential issues:
- This is local-only in the active shell.
- It does not yet appear to sync across devices.

### Add/edit health condition

User goal:
Tell the app about relevant health context.

Steps:
1. During onboarding or baseline review, select conditions.
2. Optionally add notes.
3. Save baseline.

Inputs used:
- Health condition selections
- Optional notes

Expected output:
- Daily plan wording adjusts
- Health context note appears where relevant

Current status:
- Partially working

Potential issues:
- In the active shell, health conditions appear to be managed through baseline review rather than a dedicated edit screen.
- Backend health-condition APIs exist, but the active shell does not appear to rely on them.

### View adaptive coach update

User goal:
Get a compact, intelligent course-correction summary.

Steps:
1. Open Plan.
2. Review Adaptive Coach Update.
3. See plan mode, next best action, and nudges.

Inputs used:
- Base targets
- Current intake
- Steps and activity progress
- Readiness
- Workout state
- 7-day trends
- Supplements due/taken
- Health context

Expected output:
- Plan mode
- One next best action
- Up to 3 nudges

Current status:
- Working

Potential issues:
- Users may not immediately understand that adaptive advice is intentionally changing while base targets remain stable.

### View diet suggestions

User goal:
See meal ideas that match the current day.

Steps:
1. Open Plan.
2. Go to Meal ideas for today.
3. Review breakfast, dinner, and snack suggestions.
4. If a meal is already logged for a meal type, see the logged meal instead.

Inputs used:
- Goal
- Remaining calories
- Remaining protein
- Readiness
- Conditions
- Workout context
- Meal logs
- Suggestion history

Expected output:
- Compact meal suggestions with calories, protein, and portion guidance

Current status:
- Working

Potential issues:
- Lunch suggestions exist in the data model but are intentionally hidden in the current UI.
- This may be acceptable or may signal an incomplete product decision.

### View progress

User goal:
Review weekly trend and consistency.

Steps:
1. Open Progress.
2. Review readiness bar chart.
3. Review weekly trend summary.
4. Review consistency score.

Inputs used:
- Weekly readiness
- Weekly intake/burn summary
- Weekly consistency summary

Expected output:
- Compact weekly overview

Current status:
- Working

Potential issues:
- The screen is intentionally slim and may feel too light if users expect deeper nutrition or exercise history.

### Use Journey tab

User goal:
Track walking progress as a travel game.

Steps:
1. Open Journey.
2. Review route progress, city cards, stats, rewards, unlockables, mission, and badges.
3. Re-sync Health if needed.

Inputs used:
- Apple Health steps
- User height if available
- Local Journey logs and progress

Expected output:
- Distance walked
- Current city
- Next city
- Points
- Level/title
- Mission and badges

Current status:
- Working

Potential issues:
- If Apple Health is disconnected, Journey is blocked until Health sync succeeds.
- Journey is local-only, so reinstalling the app may reset progress.

### Change journey route

User goal:
Switch between different route challenges.

Steps:
1. Open Journey.
2. Tap route selector.
3. Choose a different route.
4. Confirm switch.

Inputs used:
- Selected challenge
- Per-route progress

Expected output:
- New route appears
- Existing route progress remains stored separately

Current status:
- Working

Potential issues:
- Users need clearer education that progress is separate per route rather than one universal distance pool.

### Earn points/badges/titles

User goal:
Get rewarded for walking consistency and milestones.

Steps:
1. Walk and sync Apple Health.
2. Daily logs update.
3. Points and milestones are recalculated.
4. Open badges to see earned and locked items.

Inputs used:
- Steps
- Daily mission completion
- Route milestones
- Streaks
- Total distance

Expected output:
- Explorer points
- Level and title
- Unlockable counts
- Badge detail views

Current status:
- Working

Potential issues:
- All reward state is local-only.
- Progress and achievements likely do not survive app reinstall.

## 4. Feature-by-Feature Review

### Feature: Onboarding

What it does:
Collects the user’s basic baseline so BeU can personalize goals and plan copy.

Where it appears:
- First launch
- Profile baseline review

Inputs:
- Name
- Gender
- Age
- Height
- Weight
- Medical conditions
- Supplement list

Logic summary:
The app stores a single baseline profile locally and uses it as the foundation for the rest of the app.

Output:
- Saved baseline profile
- Ability to proceed to goal setup

Dependencies:
- Local store

Current status:
- Working

Risks:
- Only one baseline profile exists.
- No multi-user/device concept is visible.

### Feature: Goal Setup

What it does:
Lets the user choose a wellness goal and timeline, then computes daily targets.

Where it appears:
- Immediately after onboarding
- Profile tab via “Change goal”

Inputs:
- Goal type
- Target weight
- Timeline
- Baseline body data

Logic summary:
The app derives calorie and protein targets based on the selected goal and body profile.

Output:
- Goal config
- Daily calorie and protein targets

Dependencies:
- Local goal store
- Local plan service

Current status:
- Working

Risks:
- Users may not understand why base targets differ from adaptive recommendations later in the day.

### Feature: Apple Health Sync

What it does:
Imports activity and recovery data from Apple Health.

Where it appears:
- Home
- Plan
- Progress
- Journey
- Profile health status

Inputs:
- Steps
- Active energy
- Basal energy
- Workouts
- Sleep
- HRV
- Resting heart rate

Logic summary:
The app requests HealthKit authorization and tries to load real data. If that fails, the gateway falls back to prototype data.

Output:
- Current signals
- Readiness
- Weekly readiness series
- Journey step input

Dependencies:
- Apple Health
- Local gateway/service layer

Current status:
- Partially working

Risks:
- Prototype fallback can mask failed Health sync.
- Users may think they are seeing their real data when they are not.

### Feature: Readiness Score

What it does:
Summarizes recovery based on recent sleep, HRV, resting heart rate, and yesterday’s activity load.

Where it appears:
- Home
- Plan
- Progress

Inputs:
- Sleep
- HRV
- Resting heart rate
- Yesterday activity load
- Recent summaries for averages

Logic summary:
The app uses a weighted readiness model, including a neutral sleep fallback if sleep data is missing. Missing HRV/RHR/activity are excluded rather than forced to zero.

Output:
- Score
- Status
- One-line message
- Contributing factors
- Available/missing signals internally

Dependencies:
- Apple Health
- Local readiness logic

Current status:
- Working

Risks:
- Because a readiness score can still be shown when data is incomplete, some users may over-trust the number.

### Feature: Home Screen

What it does:
Provides a compact daily summary.

Where it appears:
- Home tab

Inputs:
- Greeting name
- Readiness
- Daily targets
- Health status
- Daily plan
- Weekly insight summary

Logic summary:
The screen is intentionally concise and acts as a launchpad into the full Plan and Progress views.

Output:
- Readiness card
- Today’s targets card
- Apple Health card
- Today’s plan card
- Weekly snapshot card

Dependencies:
- Local plan engine
- Apple Health
- Local meal/water state

Current status:
- Working

Risks:
- If Apple Health is disconnected, users may still see plan behavior influenced by prototype values.

### Feature: Plan Screen

What it does:
Shows the detailed daily action plan.

Where it appears:
- Plan tab

Inputs:
- DailyPlan
- AdaptivePlanOutput
- DietGuidance
- Meals today
- Supplement taken state
- Health context

Logic summary:
The plan keeps stable base targets and adds adaptive coaching on top of them.

Output:
- Intake & Burn
- Adaptive Coach Update
- Water Intake
- Today’s Training
- Sleep Requirement
- Meal ideas
- What to prioritize
- Supplement Reminder
- Why this plan

Dependencies:
- Local plan/adaptive services
- Apple Health
- Local meal/water/supplement state

Current status:
- Working

Risks:
- The plan is rich and useful, but it is built locally in the active shell rather than fetched from the backend plan endpoints.

### Feature: Log Meal Flow

What it does:
Handles meal entry, meal analysis review, nutrition estimate, and saving.

Where it appears:
- Log Meal bottom action

Inputs:
- Text description or image
- Meal type
- Review item edits

Logic summary:
Text and photo logging converge into the same review-and-confirm flow before saving.

Output:
- Saved meal log
- Updated daily counters

Dependencies:
- Local meal log persistence
- Backend meal analysis for text/image

Current status:
- Working

Risks:
- Complex state machine in one sheet means regressions are likely without frequent real-device testing.

### Feature: Text Meal Analysis

What it does:
Sends a typed meal description to the backend for structured food estimation.

Where it appears:
- Log Meal → Describe in words

Inputs:
- Description
- Meal type
- Diet preference

Logic summary:
The app sends the request to the Render backend, which uses OpenAI and returns structured detected items and totals.

Output:
- Original description
- Detected items
- Totals
- Confidence

Dependencies:
- Render backend
- OpenAI via backend

Current status:
- Partially working

Risks:
- Recently modified path; needs end-to-end validation on device.

### Feature: Photo Meal Analysis

What it does:
Uploads a meal image for food estimation.

Where it appears:
- Log Meal → Take photo / Choose from library

Inputs:
- Uploaded image
- User ID

Logic summary:
The app posts a multipart image request to the backend and receives a structured analysis.

Output:
- Detected items
- Totals
- Confidence

Dependencies:
- Camera or Photos access
- Render backend
- OpenAI via backend

Current status:
- Partially working

Risks:
- Depends on permissions, image upload correctness, backend availability, and cold-start latency on Render free tier.

### Feature: Meal Edit/Delete

What it does:
Allows users to edit existing meals or delete them safely.

Where it appears:
- Log Meal → Previously Logged Meals
- Plan meal sections for logged meals

Inputs:
- Existing meal logs
- Edited items

Logic summary:
Meals can be reopened into the same review editor used for analysis results. Delete shows confirmation and triggers local refresh.

Output:
- Updated meal
- Deleted meal
- Refreshed daily totals

Dependencies:
- Local meal storage

Current status:
- Partially working

Risks:
- This area has had recent crash fixes and still deserves high-confidence testing.

### Feature: Daily Nutrition Counters

What it does:
Tracks calories, protein, carbs, fat, water, and meal count for the current day.

Where it appears:
- Home
- Plan
- Log Meal side effects

Inputs:
- Meal logs
- Water progress
- Steps

Logic summary:
The active shell recalculates daily counters from local meal logs and local water state.

Output:
- Consumed/remaining progress
- Progress bars

Dependencies:
- Local persistence
- Apple Health for steps

Current status:
- Working

Risks:
- Because the active shell is local-first, backend and multi-device consistency are limited.

### Feature: Diet Suggestions

What it does:
Generates dynamic meal ideas based on the user’s goal, remaining calories/protein, readiness, conditions, and recent suggestion history.

Where it appears:
- Plan → Meal ideas for today

Inputs:
- Goal
- Readiness
- Intake remaining
- Health context
- Meal history
- Suggestion history

Logic summary:
The app scores a meal library and rotates suggestions to avoid repetition.

Output:
- Breakfast ideas
- Dinner ideas
- Snack ideas

Dependencies:
- Local diet guidance engine
- Suggestion history store

Current status:
- Working

Risks:
- Lunch exists in data but not in active UI, which could create product confusion.

### Feature: Adaptive Coaching Engine

What it does:
Provides day-specific recommendation text without constantly changing the base targets.

Where it appears:
- Home Today’s Plan summary
- Plan Adaptive Coach Update
- Training guidance
- Meal guidance language

Inputs:
- Stable targets
- Current progress
- Readiness
- Time of day
- 7-day performance trends
- Workout state
- Supplements due/taken

Logic summary:
The engine assigns a plan mode such as recovery-first, protein-behind, or activity-ahead, then generates compact advice.

Output:
- Plan mode
- Calorie/protein/activity/strength advice
- Meal focus
- Next best actions
- Nudges

Dependencies:
- Local adaptive plan service
- Local nudge service

Current status:
- Working

Risks:
- More sophisticated than the rest of the app, so users may need clearer product explanation for why the advice changes even when targets do not.

### Feature: Supplements

What it does:
Stores the user’s recurring supplement list and tracks whether today’s supplement was taken.

Where it appears:
- Onboarding baseline
- Profile baseline summary
- Plan supplement reminder

Inputs:
- Supplement name
- Dosage
- Timing
- Frequency
- Today’s taken status

Logic summary:
The recurring supplement profile is stored with the baseline, while daily “taken” state is stored separately by date.

Output:
- Supplement reminders
- Due today / due later / taken state

Dependencies:
- Local baseline storage
- Local supplement intake log repository

Current status:
- Working

Risks:
- Active shell does not appear to use backend supplement CRUD even though backend endpoints exist.

### Feature: Health History / Conditions

What it does:
Lets the user tell BeU about conditions like PCOS or diabetes so plan wording can adapt.

Where it appears:
- Onboarding baseline
- Profile baseline summary
- Plan context notes

Inputs:
- Condition chips
- Optional notes

Logic summary:
The app primarily uses conditions to change wording and emphasis, not treatment or medical advice.

Output:
- Health context note
- Safer wording in diet guidance

Dependencies:
- Local baseline storage

Current status:
- Partially working

Risks:
- Dedicated management outside baseline review is limited in the active shell.
- Backend health-condition CRUD exists but appears more tied to legacy flows.

### Feature: Progress Screen

What it does:
Shows a compact weekly progress summary.

Where it appears:
- Progress tab

Inputs:
- Weekly readiness
- Weekly insight summary
- Consistency summary

Logic summary:
The screen emphasizes direction and consistency rather than detailed logs.

Output:
- Readiness bar chart
- Weekly trend
- Consistency card

Dependencies:
- Local insights service
- Apple Health
- Local meal history

Current status:
- Working

Risks:
- Lightweight scope may not satisfy users who expect richer historical reporting.

### Feature: Journey / Travel Trail

What it does:
Turns Apple Health steps into virtual travel progress across selected routes.

Where it appears:
- Journey tab

Inputs:
- Daily step summaries
- User height if available
- Route selection

Logic summary:
The app stores per-day step distance logs per route, recalculates progress from those logs, and awards points/achievements.

Output:
- Travel progress
- Current city / next city
- Mission
- Rewards
- Unlockables
- Badges

Dependencies:
- Apple Health
- Local Journey service

Current status:
- Working

Risks:
- Local-only persistence means reinstall/device changes can reset or fragment progress.

### Feature: Backend Integration

What it does:
Supports hosted API calls for health check, meal analysis, and several broader nutrition/profile endpoints.

Where it appears:
- Warm-up / health status
- Meal analysis
- Legacy nutrition/profile flows

Inputs:
- API requests from iOS

Logic summary:
The codebase supports many backend endpoints, but the active shell uses only part of them directly.

Output:
- Backend health status
- Meal analysis responses
- Additional remote CRUD in legacy flows

Dependencies:
- Render-hosted Node backend

Current status:
- Partially working

Risks:
- Product behavior is split between local-first active shell and backend-backed legacy services.

### Feature: Render-hosted API Usage

What it does:
Points the app at the hosted backend instead of localhost.

Where it appears:
- Central API configuration

Inputs:
- APIConfig base URL

Logic summary:
The app uses `https://beu-backend-zxxo.onrender.com` as the default backend and can optionally override it via Info.plist.

Output:
- Hosted backend access

Dependencies:
- Render

Current status:
- Working

Risks:
- Render free-tier sleeping can delay the first request.

### Feature: OpenAI Meal Analysis Usage

What it does:
Uses OpenAI through the backend for text and image-based meal estimation.

Where it appears:
- Text analysis
- Image analysis

Inputs:
- Text description
- Meal photo

Logic summary:
The backend wraps OpenAI calls and returns structured food-analysis JSON to the app.

Output:
- Detected items
- Total calories/protein/carbs/fat
- Confidence
- Notes

Dependencies:
- Render backend
- OpenAI backend config

Current status:
- Working

Risks:
- If the backend or OpenAI fails, meal analysis becomes unavailable.

### Feature: Local Persistence / Saved State

What it does:
Keeps major user data on-device.

Where it appears:
- Across the full app

Inputs:
- Baseline
- Goals
- Meals
- Water
- Supplement taken logs
- Journey state

Logic summary:
The active shell relies heavily on local files and UserDefaults.

Output:
- State survives app restarts on the same device

Dependencies:
- Application Support
- UserDefaults

Current status:
- Working

Risks:
- Cross-device continuity is weak.
- Reinstall behavior varies by data type.

### Feature: Error States and Empty States

What it does:
Gives feedback when data is missing or a flow fails.

Where it appears:
- Log Meal
- Journey
- Backend health status
- Apple Health status

Inputs:
- API failures
- Missing Health permissions
- Missing meals
- Missing journey data

Logic summary:
The app uses lightweight alerts, messages, and empty cards rather than full-screen blockers.

Output:
- “No meals logged yet today.”
- “Meal analysis failed. Please try again.”
- “Connect Apple Health to start your journey.”
- “No steps synced yet today.”
- Backend status labels

Dependencies:
- Local UI state
- Backend
- Apple Health

Current status:
- Working

Risks:
- Health fallback to prototype data is more subtle than an explicit error state.

### Feature: Bottom Navigation

What it does:
Provides the main app shell.

Where it appears:
- Main app

Inputs:
- Selected tab state

Logic summary:
The app uses a floating glass-style bottom bar with tabs and a central Log Meal action.

Output:
- Home
- Plan
- Log Meal action
- Journey
- Progress
- Profile

Dependencies:
- Local shell state

Current status:
- Working

Risks:
- Log Meal is visually part of the nav but technically opens a sheet rather than a dedicated tab, which is acceptable but worth documenting.

## 5. Data Inputs and Data Usage

| Data input | Source | Used for | Screens affected |
|---|---|---|---|
| Name | Local onboarding baseline | Greeting, profile identity | Home, Profile |
| Age | Local onboarding baseline | Goal estimation, plan targets | Goal setup, Plan, Profile |
| Gender | Local onboarding baseline | Goal estimation | Goal setup, Plan, Profile |
| Height | Local onboarding baseline and/or Health summary | Goal estimation, Journey step-length estimate | Goal setup, Plan, Journey, Profile |
| Weight | Local onboarding baseline and/or Health summary | Goal estimation | Goal setup, Plan, Profile |
| Target weight | Local goal config | Goal framing and target previews | Goal setup, Profile, Plan |
| Goal | Local goal config | Plan targets, adaptive coaching, meal suggestions | Home, Plan, Profile |
| Timeline | Local goal config | Goal framing and target guidance | Goal setup, Profile, Plan |
| Supplements | Local baseline profile | Daily supplement reminder list | Onboarding, Profile, Plan |
| Health conditions | Local baseline profile | Health context notes, wording changes | Onboarding, Profile, Plan |
| Steps | Apple Health or prototype fallback | Targets card, Journey, adaptive coaching, burn/progress | Home, Plan, Progress, Journey |
| Active energy | Apple Health or prototype fallback | Burn tracking, adaptive coaching, readiness context | Home, Plan, Progress |
| Basal energy | Apple Health or prototype fallback | Total burn estimate | Plan, backend health summary model |
| Workout calories | Apple Health or prototype fallback | Energy balance, refuel/recovery guidance | Plan, adaptive coaching |
| Sleep | Apple Health or prototype fallback | Readiness, sleep requirement | Home, Plan, Progress |
| HRV | Apple Health or prototype fallback | Readiness | Home, Plan, Progress |
| Resting heart rate | Apple Health or prototype fallback | Readiness | Home, Plan, Progress |
| Meal logs | Local meal store in active shell | Daily counters, meal history, adaptive plan, diet suggestions | Home, Plan, Log Meal, Progress |
| Calories consumed | Derived from meal logs | Daily targets, adaptive coaching, plan mode | Home, Plan |
| Protein consumed | Derived from meal logs | Protein guidance, meal suggestions, adaptive coaching | Home, Plan |
| Journey distance | Derived from daily Journey logs | Route progress, city unlocks, badges | Journey |
| Supplement taken logs | Local supplement intake log repository | Daily supplement statuses | Plan |

## 6. Backend and API Review
The codebase supports a fairly broad backend, but the active app shell uses only part of it directly.

What actively appears to call the backend now:
- `/health` warm-up and backend status check
- `/api/food/analyze-text`
- `/api/food/analyze-image`

What exists in the client and backend but appears more tied to older or secondary flows:
- nutrition profile CRUD
- meal log fetch/save/delete endpoints
- nutrition progress fetch
- weekly nutrition summary
- weekly plan / weekly insights endpoints
- supplement CRUD endpoints
- health condition CRUD endpoints
- diet recommendation endpoint
- health summary persistence endpoints

Whether app uses Render backend URL:
- Yes. The active API config points to `https://beu-backend-zxxo.onrender.com`.

Whether any localhost references remain:
- No active production iOS localhost endpoint was found.
- Remaining localhost references are in backend example request scripts and backend console logging, not active iOS API configuration.

What happens if backend is unavailable:
- Backend status becomes `Backend unavailable`.
- Meal analysis fails with a user-facing error.
- The rest of the active local-first shell can still function to some extent because many features are local.

What happens if Render is asleep:
- App warms up `/health` on launch and foreground.
- The Log Meal loading copy can say: “Waking BeU analysis engine. This may take a few seconds.”

Whether mock/default data exists in production:
- For Apple Health: yes, prototype fallback exists in the gateway when Health data fails.
- For active meal analysis: current active text/photo path is intended to use the real backend, not a mock fallback.

| Feature | Backend endpoint | Uses OpenAI | Expected response | Error handling |
|---|---|---|---|---|
| Backend health warm-up | `GET /health` | No | backend status JSON | Marks backend connected or unavailable |
| Text meal analysis | `POST /api/food/analyze-text` | Yes | structured food analysis with detected items and totals | User sees meal analysis error message |
| Image meal analysis | `POST /api/food/analyze-image` | Yes | structured food analysis with detected items and totals | User sees meal analysis error message |
| Update reviewed image analysis | `PUT /api/food/analysis/:analysisId/items` | Indirectly | updated structured analysis | Review flow shows update error |
| Meal log CRUD | `/api/meal-log...` | No | meal logs or success | Supported in client/backend, but active shell appears local-first |
| Nutrition progress | `GET /api/nutrition-progress/:userId/:date` | No | daily progress totals | Used in legacy/secondary view model |
| Weekly nutrition summary | `GET /api/weekly-nutrition-summary/:userId` | No | weekly nutrition summary | Used in legacy/secondary view model |
| Plan endpoints | `GET /api/plan/:userId/today`, `GET /api/plan/:userId/week` | No | plan payloads | Present, but active shell builds plan locally |
| Water logging | `POST /api/plan/log-water` | No | water response | Present, but active shell currently uses local water store |
| Supplement CRUD | `/api/supplements...` | No | supplement list/items | Present, but active shell mainly uses baseline-local supplements |
| Health conditions CRUD | `/api/health-conditions...` | No | condition list/items | Present, but active shell mainly uses baseline-local conditions |

## 7. OpenAI Usage Review
OpenAI is used for food analysis, not for the rest of the app’s planning logic in the active shell.

Where OpenAI is used:
- Text meal analysis
- Image meal analysis

What prompts are likely used:
- The backend text-analysis service includes a structured nutrition-estimation prompt for meal descriptions, including guidance for Indian meals and strict JSON output.
- The image-analysis path is handled through a dedicated OpenAI vision service in the backend.

Whether API key is backend-only:
- Yes. The OpenAI API key is configured on the backend, not in iOS.

What happens if OpenAI fails:
- Backend returns a user-facing analysis failure response.
- The iOS app shows a user-facing error rather than silently inserting a fake meal.

Whether fallback/default values are used:
- For active text/photo analysis, the current active flow is intended to use backend results and show errors on failure.
- A mock analysis service still exists in the codebase, but it does not appear to be the active production path in the current meal sheet.

Whether user sees clear error messages:
- Yes, generally:
  - “Meal analysis failed. Please try again.”
  - “We couldn’t estimate this meal. Try adding more detail or log items manually.”
  - “Meal analysis is unavailable right now. Please try again.”

Text meal analysis review:
- Backend endpoint exists and is hosted on Render.
- iOS request path is correct.
- Response decoding has been hardened.
- Product status is still “partially working” until device testing confirms it end-to-end.

Image meal analysis review:
- Backend endpoint exists and is hosted on Render.
- iOS upload path exists.
- Product status is also “partially working” pending real camera/gallery validation.

## 8. Apple Health Usage Review
The app requests or derives these Apple Health-related inputs:

- Steps
- Active energy
- Basal energy
- Workouts
- Sleep
- HRV
- Resting heart rate

What each is used for:
- Steps:
  - Home targets
  - Plan activity guidance
  - Journey progress
  - Progress summaries
- Active energy:
  - Intake & Burn
  - adaptive activity guidance
  - energy balance context
- Basal energy:
  - total burn estimate
- Workouts:
  - training/refuel logic
  - energy balance
- Sleep:
  - readiness
  - sleep requirement messaging
- HRV:
  - readiness
- Resting heart rate:
  - readiness

Which screens depend on it:
- Home
- Plan
- Progress
- Journey
- Profile health status

What happens if permissions are missing:
- HealthKitGateway falls back to prototype summaries and marks Health as not connected.
- Journey uses an explicit empty/disconnected state.
- Other parts of the app can still produce numbers using fallback data.

What happens if data is missing:
- Readiness uses fallback/normalization logic.
- Journey shows a “No steps synced yet today” state if no data is available but Health is connected.

Whether simulator limitations are handled:
- The app has some resilience through fallback logic, but true Health behavior should be validated on a real iPhone.

Main product risk:
- Prototype fallback improves continuity, but it can weaken user trust because the app can still look “alive” even when real Health data is unavailable.

## 9. Local Persistence Review

### User profile
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Application Support `baseline.json`
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Single-profile local storage only

### Goal
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Application Support `goal.json`
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Local-only in the active shell

### Meal logs
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - UserDefaults
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Active shell is local-first even though backend meal-log endpoints exist

### Supplement profile
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Inside baseline profile storage
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Active supplement profile is tied to baseline rather than a dedicated remote profile model

### Supplement taken status
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - UserDefaults via supplement intake log repository
- Whether it resets unexpectedly:
  - Should persist for the same local day
- Any risk:
  - Local-only, not cross-device

### Health conditions
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Inside baseline profile storage
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Active shell relies on baseline-local conditions despite backend condition CRUD existing

### Journey progress
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Local persistence in JourneyService
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Reinstall likely resets local journey state

### Badges/points/titles
- Saved or not saved:
  - Saved
- Where it appears to be saved:
  - Local Journey persistence
- Whether it resets unexpectedly:
  - Not expected on normal restart
- Any risk:
  - Local-only; reinstall/device migration risk

### Remote config if present
- Saved or not saved:
  - Not found as a real feature
- Where it appears to be saved:
  - No remote config feature found
- Whether it resets unexpectedly:
  - Not applicable
- Any risk:
  - None specific

## 10. Screen-by-Screen Review

### Onboarding
- Screen purpose:
  - Capture body profile, health context, supplements, and baseline summary
- Main UI elements:
  - Welcome step
  - Body profile step
  - Health context chips
  - Supplement list/editor
  - Summary step
- Actions available:
  - Continue, go back, add supplement, edit supplement, confirm
- Data shown:
  - Entered baseline data
- Empty states:
  - No supplements yet
- Error states:
  - Light validation for name/body fields
- Any confusing/redundant UI:
  - None major

### Goal setup
- Screen purpose:
  - Define user goal and timeline
- Main UI elements:
  - Goal cards
  - Target weight
  - Timeline chips
  - Goal preview card
- Actions available:
  - Save goal
- Data shown:
  - Estimated calories/protein
- Empty states:
  - Not relevant
- Error states:
  - Minimal; mostly input clamping
- Any confusing/redundant UI:
  - Goal preview can be mistaken for dynamic daily targets if not explained

### Home
- Screen purpose:
  - Show concise daily summary
- Main UI elements:
  - Greeting
  - Readiness card
  - Today’s targets
  - Apple Health card
  - Today’s plan summary
  - Weekly snapshot
- Actions available:
  - Open Plan
  - Open Progress
- Data shown:
  - Readiness, targets, current health metrics, plan summary
- Empty states:
  - Apple Health card hides if not connected
- Error states:
  - None explicit besides health connection fallback
- Any confusing/redundant UI:
  - None major

### Plan
- Screen purpose:
  - Show the full day’s recommended focus
- Main UI elements:
  - Intake & Burn
  - Adaptive Coach Update
  - Water
  - Training
  - Sleep
  - Meal ideas
  - Priorities
  - Supplement reminder
  - Why this plan
- Actions available:
  - Edit/delete logged meals
  - Mark supplements taken
  - Open baseline or goal only via Profile, not directly here
- Data shown:
  - Daily plan, adaptive plan, meal logs, supplement state
- Empty states:
  - No supplement reminders
- Error states:
  - Limited explicit error UI
- Any confusing/redundant UI:
  - Lunch suggestions exist in data but are hidden in UI

### Log Meal
- Screen purpose:
  - Start meal logging and review today’s meals
- Main UI elements:
  - Take photo
  - Describe in words
  - Choose from library
  - Log water
  - Previously logged meals
- Actions available:
  - Start text/photo flow
  - Edit meal
  - Delete meal
  - Log water
- Data shown:
  - Existing meals and water progress
- Empty states:
  - No meals logged yet today
- Error states:
  - Alert-based errors
- Any confusing/redundant UI:
  - None major

### Review detected items
- Screen purpose:
  - Let user correct analysis output
- Main UI elements:
  - “You said” card for text
  - Editable item rows
  - Add missing item
  - Confirm items
- Actions available:
  - Edit, remove, add, confirm
- Data shown:
  - Detected items and per-item macros
- Empty states:
  - Can add missing item manually
- Error states:
  - Add-at-least-one-item validation
- Any confusing/redundant UI:
  - Per-item confirmed toggle may be redundant

### Estimated nutrition
- Screen purpose:
  - Show totals before final logging
- Main UI elements:
  - Macro blocks
  - Meal type selector
  - Log meal button
- Actions available:
  - Log meal
- Data shown:
  - Total calories, protein, carbs, fat
- Empty states:
  - None
- Error states:
  - Indirect via previous step
- Any confusing/redundant UI:
  - None major

### Previously logged meals
- Screen purpose:
  - Let user see, edit, and delete today’s meals
- Main UI elements:
  - Meal cards by meal type/time
  - Macro summary
  - Edit/Delete actions
- Actions available:
  - Edit
  - Delete
- Data shown:
  - Meal type, time, summary, macros
- Empty states:
  - No meals logged yet today
- Error states:
  - Delete failure alert
- Any confusing/redundant UI:
  - None major

### Progress
- Screen purpose:
  - Show weekly readiness and consistency
- Main UI elements:
  - Readiness bar chart
  - Weekly trend card
  - Consistency card
- Actions available:
  - None major
- Data shown:
  - Weekly readiness and weekly energy summary
- Empty states:
  - Not explicit
- Error states:
  - Not explicit
- Any confusing/redundant UI:
  - Could feel too light relative to the rest of the app

### Journey
- Screen purpose:
  - Turn steps into virtual route progress
- Main UI elements:
  - Header
  - Route selector
  - Hero route card
  - City carousel
  - Stats
  - Rewards
  - Unlockables
  - Mission
  - Badges preview
- Actions available:
  - Change route
  - Open badges
  - Sync Health
- Data shown:
  - Distance, progress, points, title, mission, badges
- Empty states:
  - Connect Health
  - No steps synced yet today
- Error states:
  - Health disconnected fallback state
- Any confusing/redundant UI:
  - Route-specific separate progress may need stronger explanation

### Badges
- Screen purpose:
  - Show earned and locked Journey achievements
- Main UI elements:
  - Filter chips
  - Badge grid
  - Badge detail sheet
- Actions available:
  - Filter by all/earned/locked
  - Open badge detail
- Data shown:
  - Progress, earned state, descriptions
- Empty states:
  - None explicit
- Error states:
  - None explicit
- Any confusing/redundant UI:
  - None major

### Profile
- Screen purpose:
  - Show baseline, goal, and connection state
- Main UI elements:
  - Identity card
  - Baseline card
  - Goal card
  - Health data card
- Actions available:
  - Review baseline
  - Change goal
- Data shown:
  - Profile info
  - Goal info
  - Connection status
- Empty states:
  - Not explicit
- Error states:
  - Shows prototype data / backend status labels rather than fuller error states
- Any confusing/redundant UI:
  - Supplements and health conditions are visible as counts/context but not given dedicated edit screens here

### Supplements
- Screen purpose:
  - Add recurring supplements and track today’s completion
- Main UI elements:
  - Baseline supplement list/editor
  - Plan reminder list
- Actions available:
  - Add/edit/delete in onboarding/baseline review
  - Mark taken / Undo in Plan
- Data shown:
  - Name, timing, frequency, taken state
- Empty states:
  - No supplements yet
  - No supplement reminders right now
- Error states:
  - Limited explicit error UI in active shell
- Any confusing/redundant UI:
  - Split between recurring supplement profile and daily taken status may not be obvious to users, although it is the correct data model

### Health history
- Screen purpose:
  - Capture contextual conditions and notes
- Main UI elements:
  - Condition chips
  - Notes field
- Actions available:
  - Select/deselect conditions
- Data shown:
  - Selected conditions and optional notes
- Empty states:
  - None needed
- Error states:
  - None explicit
- Any confusing/redundant UI:
  - In the active shell, updating this later means re-entering baseline review rather than opening a dedicated health-history management screen

## 11. Known Gaps / Issues / Risks

### Critical

#### Mixed local-first and backend-backed product behavior
- Description:
  - The active shell stores many core things locally even though backend endpoints for similar data also exist.
- Where it happens:
  - Meals, plan generation, supplements, health conditions, water, Journey
- Why it matters:
  - This creates ambiguity about the source of truth and limits multi-device reliability.
- Suggested fix direction:
  - Decide which data should be authoritative locally vs remotely and align the active shell to that decision.

#### Apple Health prototype fallback can mask real data problems
- Description:
  - If Health data fails, the gateway falls back to prototype/demo data.
- Where it happens:
  - HealthKitGateway, Home, Plan, Progress
- Why it matters:
  - Users and testers may think the app is using their real health data when it is not.
- Suggested fix direction:
  - Make prototype mode explicit or separate it from production behavior.

### High

#### Meal analysis needs full real-device regression testing
- Description:
  - Text and photo analysis flows have been changed recently and are backend-dependent.
- Where it happens:
  - Log Meal
- Why it matters:
  - This is a core trust and utility flow.
- Suggested fix direction:
  - Run full device QA across text, camera, gallery, edit, delete, and counter refresh.

#### Meal delete/edit area has recent stability history
- Description:
  - Delete and edit logic has recently been hardened after crashes.
- Where it happens:
  - Log Meal
  - Plan logged-meal cards
- Why it matters:
  - If this fails, users lose trust quickly.
- Suggested fix direction:
  - Add regression tests or at minimum a strong manual QA checklist.

#### Active shell and legacy flows coexist
- Description:
  - The repo still contains older dashboard/nutrition flows alongside the active Engine shell.
- Where it happens:
  - DashboardView, DashboardViewModel, NutritionFlowViews, NutritionViewModel
- Why it matters:
  - Product and QA can become confused about which behavior is real.
- Suggested fix direction:
  - Consolidate toward one shell or clearly isolate legacy/demo flows.

### Medium

#### Health conditions and supplements are awkward to edit after onboarding
- Description:
  - The active shell mostly routes these through baseline review rather than dedicated profile management screens.
- Where it happens:
  - Profile / baseline review
- Why it matters:
  - Ongoing user maintenance feels heavier than it should.
- Suggested fix direction:
  - Add dedicated edit surfaces in the active shell.

#### Lunch suggestions exist in logic but not in active Plan UI
- Description:
  - The data model supports breakfast/lunch/dinner/snacks, but the active UI focuses on breakfast, dinner, and snacks.
- Where it happens:
  - Plan → Meal ideas for today
- Why it matters:
  - This may be a conscious simplification or an incomplete feature.
- Suggested fix direction:
  - Make a product decision and align logic/UI.

#### Journey is local-only
- Description:
  - Journey progress, points, and badges are not clearly cloud-backed.
- Where it happens:
  - Journey
- Why it matters:
  - Reinstall/device changes can break continuity.
- Suggested fix direction:
  - Decide whether Journey should remain a local game or become a persistent account feature.

### Low

#### Some product explanations may not make target stability obvious
- Description:
  - Base targets are stable while adaptive advice changes.
- Where it happens:
  - Home and Plan
- Why it matters:
  - Users may think the app is inconsistent rather than adaptive.
- Suggested fix direction:
  - Add lightweight product copy explaining the model.

#### Review screen has a possibly redundant confirmation control
- Description:
  - There is both a per-item confirmed toggle and a global confirm action.
- Where it happens:
  - Review detected items
- Why it matters:
  - Minor confusion risk.
- Suggested fix direction:
  - Clarify the purpose of the toggle or simplify it.

## 12. Product Review Questions
- Should meal logs remain local-first, or should the backend become the source of truth?
- Should BeU ever allow multiple users or multi-device continuity?
- Should Apple Health failure show a strict disconnected state instead of prototype/demo data?
- Should the active shell use backend plan endpoints, or should plan generation stay local?
- Should supplements remain reminders only, or become a fuller adherence feature?
- Should health conditions be editable from a dedicated Profile screen instead of baseline review?
- Should lunch suggestions appear in the active Plan UI?
- Should Journey remain local-only, or be synced per account?
- Should route switching share one global walking pool or keep separate progress per route?
- Should the Progress tab stay lightweight, or become a more detailed historical dashboard?
- Should the app explicitly explain the difference between stable targets and adaptive coaching?
- Should Profile remain mostly read-only, or become a true settings/management area?

## 13. Final App Summary
BeU today is a polished single-user wellness app with strong daily-planning ambition: onboarding, goals, Health-driven readiness, adaptive plan guidance, meal logging with AI analysis, supplement reminders, progress summaries, and a gamified walking journey.

What feels strong:
- coherent product direction
- stable daily target philosophy with adaptive recommendation overlay
- premium UI in the active shell
- engaging Journey feature
- meal review flow concept

What needs review before sharing with users:
- the split between local-first active behavior and broader backend capabilities
- the use of prototype Apple Health fallback
- full real-device testing of meal analysis, meal delete/edit, and permission-heavy flows
- clarity around what persists locally vs remotely

What should be tested manually:
- full onboarding to goal setup
- Apple Health permission and sync success/failure cases
- text and photo meal analysis
- meal edit/delete and counter refresh
- supplement mark-taken persistence across restart
- adaptive plan updates after meals, movement, and readiness changes
- Journey route switching, point/badge updates, and Health-disconnected states
