# 02 - Data Model

## Core Entities (SwiftData)
- `FinancialAccount`: broad account types across assets, liabilities, and investments.
- `BalanceSnapshot`: periodic point-in-time account balances (+ optional contribution).
- `ExpenseSnapshot`: monthly category totals (non-granular).
- `FinancialGoal`: target amount/date with contribution plan.
- `RecurringContributionPlan`: recurring amount linked to goal/account.
- `TaxEstimateLog`: persisted tax estimate runs with source and timestamp.
- `AppSettings`: app-level preferences (currency, reminders, lock, tax metadata).

## Design Notes
- Snapshot-first storage avoids full transaction ledger complexity.
- `accountID` on snapshots avoids heavy relationship overhead for MVP speed.
- Multi-currency normalization uses manual `USD<->CAD` conversion from settings.

## Validation and Defaults
- Base currency default: USD.
- Reminder defaults: Sunday 9 PM + daily 9 PM after stale threshold.
- Embedded API key placeholder stored in settings by default.
