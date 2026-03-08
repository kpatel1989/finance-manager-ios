# 01 - Architecture

## Objective
Build Portfolio as a local-first, iPhone-first (iOS 17+) SwiftUI app with snapshot-based finance tracking.

## Layering
- `Domain`: enums, SwiftData models, protocol interfaces.
- `Services`: analytics engine, tax providers, notification scheduling, app lock, keychain, CSV transfer.
- `Features`: tab-level feature views and forms.
- `UI`: reusable formatters/card style.

## Runtime Composition
- `PortfolioApp` creates a `ModelContainer` with all models.
- `AppRootView` hosts dashboard/accounts/planner/tools/settings in `TabView`.
- `AppLockManager` overlays lock UI on foreground when enabled.
- `PortfolioNotificationScheduler` requests permissions and updates reminder schedules.

## API Contracts
- `TaxProvider.estimate(_:) async throws -> TaxEstimateResult`
- `ReminderScheduler.refreshSchedules(lastStatusUpdate:now:)`

## Edge Cases
- Missing/invalid tax API key falls back to offline provider.
- No biometric/passcode configured: app lock fails open.
- Archived accounts are excluded from analytics.
