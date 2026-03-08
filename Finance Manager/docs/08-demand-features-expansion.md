# 08 — Demand Features Expansion (Bills, Forecast, Reviews, FX, Secure Share)

## Goal
Implement the prioritized user-demand features in the local-first iOS app:
- Scheduled bills and reminders with due-date notifications (credit cards, property tax, etc.)
- Forecast calendar and bill engine
- Quick capture templates and additional app quick actions
- Goals/debt enhancements (strategy comparison)
- Advanced review snapshots (YTD/QTD/custom)
- Multi-currency FX table with dated manual rates
- Transfer handling between accounts
- Private household encrypted export/import handoff

## Scope Delivered

### Data model additions (SwiftData)
- `ScheduledItem`
- `FXRateEntry`
- `AccountTransfer`
- `FinancialReviewSnapshot`
- `QuickCaptureTemplate`
- New enums for scheduled item type/category/recurrence.

### Scheduling and notifications
- Existing weekly + stale escalation reminders preserved.
- Added due-date and advance reminders for scheduled items.
- Notifications now include:
  - due notice on due date
  - advance notice `n` days before due date
- Recomputed each app active/update cycle.

### Forecast and bill engine
- Added schedule engine (`ScheduleEngine`) to compute upcoming recurrences.
- Added analytics for:
  - upcoming due events
  - projected cashflow timeline
  - review-period metrics (net worth start/end, expenses, contributions)

### Quick capture layer
- Added `QuickCaptureTemplate` management and one-tap execution.
- Expanded app icon quick actions:
  - `Quick Update`
  - `Add Bill Reminder`
  - `Open Tools`

### Debt and reviews
- Debt planner now compares snowball vs avalanche side-by-side.
- Added advanced review snapshot creation with presets:
  - YTD
  - QTD
  - Rolling 12 months
  - Custom period

### Multi-currency v2
- Added dated FX table with manual entries.
- Analytics conversion now supports:
  - latest applicable manual FX rates
  - fallback USD/CAD setting when no manual rate exists

### Transfer handling
- Added transfer entry:
  - `from` / `to` account
  - amount and FX rate
  - transfer date and note
- Persists transfer log and applies corresponding account snapshots.

### Private household sharing
- Added encrypted package export/import service:
  - AES-GCM encryption
  - passphrase-derived key (SHA-256 based)
  - local file handoff only (no cloud dependency)

## Files Updated
- `Finance Manager/Finance Manager/Domain/FinanceModels.swift`
- `Finance Manager/Finance Manager/PortfolioApp.swift`
- `Finance Manager/Finance Manager/Features/AppRootView.swift`
- `Finance Manager/Finance Manager/Features/DashboardView.swift`
- `Finance Manager/Finance Manager/Features/PlannerView.swift`
- `Finance Manager/Finance Manager/Features/ToolsView.swift`
- `Finance Manager/Finance Manager/Features/AccountsView.swift`
- `Finance Manager/Finance Manager/Features/SettingsView.swift`
- `Finance Manager/Finance Manager/Info.plist`
- `Finance Manager/Finance Manager/Services/FinanceAnalytics.swift`
- `Finance Manager/Finance Manager/Services/PortfolioNotificationScheduler.swift`
- `Finance Manager/Finance Manager/Services/QuickActions.swift`
- `Finance Manager/Finance Manager/Services/MockDataService.swift`
- `Finance Manager/Finance Manager/Services/ScheduleEngine.swift` (new)
- `Finance Manager/Finance Manager/Services/SecureHouseholdShareService.swift` (new)

## Setup / UX Notes
- Scheduled bill/reminder management is in `Planner`.
- Demand-feature controls (reviews, FX, transfers, templates, secure sharing) are in `Tools`.
- Mock mode seeding now includes scheduled items and FX/template sample data.
- On simulator, mock mode defaults to enabled.

## Verification
- Build target: iPhone 17 Pro Max simulator (iOS 26.2)
- Command:
  - `xcodebuild -project 'Finance Manager/Finance Manager.xcodeproj' -scheme 'Finance Manager' -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -derivedDataPath /tmp/portfolio-derived CODE_SIGNING_ALLOWED=NO build`
- Result: `BUILD SUCCEEDED`
- App launch result:
  - `xcrun simctl launch ... com.portfolio.app`
  - PID returned successfully.

## Constraints / Known Tradeoffs
- Secure package key derivation uses a simple SHA-256 passphrase derivation for v1 simplicity. A stronger KDF (PBKDF2/Argon2) is recommended for a production hardening pass.
- Notification scheduler resets pending app notifications before re-scheduling to avoid stale item reminders.
- Widget extension (Home/Lock Screen) is not introduced in this phase; quick capture is implemented via templates and app quick actions.
