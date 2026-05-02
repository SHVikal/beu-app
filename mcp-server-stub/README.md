# MCP Server Stub

## Purpose
This folder documents how the existing backend can later be exposed as MCP tools without changing the core business logic.

## Why the Backend Is Ready
The backend already separates:
- repositories for persistence
- services for business logic
- controllers for HTTP

An MCP server can reuse the services directly:
- `HealthSummaryService`
- `UserGoalService`
- `DietRecommendationService`

## Suggested Future Structure
```text
mcp-server/
  src/
    server.ts
    tools/
      getDailyHealthSummary.ts
      getWeeklyHealthSummary.ts
      getUserGoal.ts
      generateDietRecommendation.ts
```

## Recommended Tool Mappings
- `get_daily_health_summary`
  - input: `userId`, `date`
  - backend service: `HealthSummaryService.getDaily`
- `get_weekly_health_summary`
  - input: `userId`, `days`
  - backend service: `HealthSummaryService.getRange`
- `get_user_goal`
  - input: `userId`
  - backend service: `UserGoalService.getByUserId`
- `generate_diet_recommendation`
  - input: `userId`, `date`
  - backend service: `DietRecommendationService.generate`

## Implementation Options
1. Direct in-process service reuse
   - Best for one mono-repo deployment
2. HTTP wrapper over backend REST endpoints
   - Best if backend and MCP server deploy separately

## Guardrails for Later
- Keep tool outputs structured and LLM-friendly
- Preserve safety notes from backend responses
- Add real authentication before exposing tools to broader agents
- Add audit logging if recommendations become externally accessible
