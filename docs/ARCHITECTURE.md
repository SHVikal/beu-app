# Architecture

## Overview
The MVP is split into three layers:

1. `ios/HealthDietCoach`
   - SwiftUI client
   - HealthKit aggregation
   - REST client for backend sync and recommendation fetch
2. `backend`
   - Express + TypeScript API
   - Repository and service layers
   - SQLite persistence for normalized summaries and user goals
3. `mcp-server-stub`
   - Future-facing tool contracts for MCP integration

## Data Flow
1. User grants HealthKit read permission in iOS app.
2. `HealthKitManager` aggregates raw samples into daily summaries.
3. `DashboardViewModel` syncs normalized summaries to backend.
4. Backend stores summary rows in SQLite.
5. Backend generates deterministic recommendation output from:
   - daily summary
   - 7-day summary context
   - user goal
6. iOS app displays structured guidance.

## Backend Design
- `controllers/`: HTTP handlers only
- `services/`: business logic and orchestration
- `repositories/`: database access
- `db/`: SQLite initialization and schema
- `validation/`: Zod schemas
- `middleware/`: shared validation and error handling

This keeps persistence swappable so SQLite can later move to Postgres with minimal service changes.

## iOS Design
- `Services/HealthKitManager.swift`
  - HealthKit authorization
  - daily aggregation
- `Services/APIClient.swift`
  - REST calls to backend
- `ViewModels/DashboardViewModel.swift`
  - permission flow
  - sync and recommendation orchestration
- `Views/`
  - dashboard, trend, permission, and recommendation UI

## Future MCP Path
The backend service layer already exposes the useful seams:
- health summary lookup
- range summary lookup
- user goal lookup
- diet recommendation generation

An MCP server can later call these service methods directly or through internal HTTP calls, depending on deployment needs.
