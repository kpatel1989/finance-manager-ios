# 06 - Testing and Release Notes

## Automated Tests Implemented
- Analytics math: net worth and projections.
- Investment growth decomposition and CAGR.
- Expense aggregation.
- Goal projection date.
- Debt payoff planner ordering behavior.
- Offline tax estimate sanity check.
- Reminder scheduler stale-threshold decision logic helper coverage.

## Manual QA Checklist
- Create all major account types.
- Add snapshots and verify dashboard updates.
- Validate weekly reminder scheduling in notification center.
- Validate app lock behavior on background/foreground.
- Validate tax fallback by removing API key.
- Validate CSV export then import round trip.

## Known Limits (v1)
- Tax estimator is projection-grade, not filing-grade.
- Home-screen quick update uses shortcut action, not full WidgetKit extension target.
