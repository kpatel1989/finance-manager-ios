# 04 - Tax Engine

## Strategy
- API-first tax estimate using API Ninjas.
- Automatic offline fallback to local progressive bracket estimator.
- Mandatory disclaimer rendered in UI.

## Providers
- `APINinjasTaxProvider`
  - Endpoint: `/v1/incometax`
  - Header: `X-Api-Key`
  - Country codes: `US`, `CA`
- `OfflineTaxProvider`
  - Simplified U.S./Canada federal bracket estimate
  - Standard deduction fallback behavior
- `HybridTaxProvider`
  - Try API first, fallback on any provider failure.

## Persistence
- `TaxEstimateLog` stores source, timestamp, details payload.
- `AppSettings.lastTaxSyncAt` stores latest update timestamp.

## Security Note
Embedded keys are extractable from binaries. Keychain override is supported for safer runtime key replacement.
