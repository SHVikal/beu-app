# BeU PRD

## Product Goal
Build a production-ready MVP that turns Apple Health / Apple Watch data into daily summaries and safe, structured diet guidance.

## Target User
- Health-conscious iPhone users with Apple Health data
- Users who want lightweight nutrition guidance without manual logging
- Early testers validating HealthKit-to-backend data flow before any LLM or MCP integration

## MVP Scope
- Read HealthKit data with explicit user permission
- Aggregate data into daily summaries for today and the last 7 days
- Persist normalized health summaries in a backend database
- Persist one user goal per user
- Generate deterministic diet recommendations based on business rules
- Display a simple SwiftUI dashboard with summary, trend, and recommendation output

## Out of Scope
- Paid APIs
- Direct LLM calls
- Medical diagnosis or treatment advice
- Wearable data writes
- Social features
- Proper auth providers

## User Stories
1. As a user, I can grant HealthKit read access for key wellness metrics.
2. As a user, I can see my current daily summary and a 7-day trend.
3. As a user, I can choose a goal like fat loss or muscle gain.
4. As a user, I can generate a diet suggestion based on recent activity and sleep.
5. As a developer, I can reuse backend services later from an MCP server.

## Success Criteria
- Backend stores and returns normalized summaries reliably
- App successfully reads supported HealthKit data on a physical iPhone
- Recommendation endpoint returns structured JSON without external APIs
- Documentation is clear enough for another developer to run locally in under 30 minutes
