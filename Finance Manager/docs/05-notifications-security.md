# 05 - Notifications and Security

## Reminder Logic
- Weekly reminder: Sunday 9:00 PM local time.
- Escalation: if no update in 7 days, add daily 9:00 PM reminder.
- Triggered recalculation after financial updates and settings changes.

## App Lock
- Face ID/passcode unlock required when app returns active (if enabled).
- App locks when moving to background.
- If no device authentication configured, lock manager falls back to unlocked state.

## Local-First Compliance
- No external account aggregation.
- No data pull/backup jobs.
- SwiftData local persistence only.
