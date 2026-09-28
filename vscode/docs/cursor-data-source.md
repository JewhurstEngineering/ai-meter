# Cursor data source

Verified against AI Meter (`AIMeterCore` `PersonalUsageClient`) on 19 August 2026. These are **undocumented personal dashboard endpoints**. They work for individual Cursor sessions today; they can change without notice.

Do not invent additional URLs. Re-check this file before changing `CursorApiClient`.

## Authentication

Cookie header:

```
Cookie: WorkosCursorSessionToken=<value>
```

`<value>` is either:

- a preformed `userId%3A%3A<jwt>` string (or `userId::<jwt>`, which is encoded to `%3A%3A`);
- or a raw JWT whose `sub` claim is extracted and encoded as `userId%3A%3A<jwt>`.

The extension stores whatever the user pastes in VS Code Secret Storage. It never writes credentials to settings or snapshot cache.

User-Agent matches the macOS app:

```
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15
```

Timeout: 20 seconds.

## Endpoints

Base: `https://cursor.com`

| Method | Path | Role |
| --- | --- | --- |
| GET | `/api/auth/me` | Validate session; `sub` / `id` required |
| GET | `/api/usage-summary` | Cursor Models / Other Models / total % / on-demand / billing cycle |
| GET | `/api/auth/stripe` | Plan membership fallback (optional; failure is ignored) |
| POST | `/api/dashboard/get-aggregated-usage-events` | Per-model spend this cycle (optional) |
| POST | `/api/dashboard/get-sand-usage-status` | Grok Bot weekly allowance (optional; failure is ignored) |

POST JSON body:

```json
{
  "teamId": 0,
  "startDate": "<cycle start unix ms>",
  "endDate": "<cycle end unix ms>",
  "userId": 12345678
}
```

Grok Bot (`Sand` in Cursor’s API) is a separate weekly allowance. Body is `{}`. Show a meter only when `hasNonZeroIncludedLimit` is true, `includedLimitZero` is not true, `usesPooledEnterpriseAllowance` is not true, and `usagePercent` is present. `usagePercent` is how much is used, 0–100. Read `nextResetTimestampUtc` when the reply includes it; do not invent a reset from the period start.

POST also sends `Origin: https://cursor.com` and `Content-Type: application/json`.

## Status handling

| HTTP | Meaning |
| --- | --- |
| 401 | Session expired — sign in again |
| 204, or 200 with empty body | Empty cycle — keep last numbers |
| 429, 5xx | Soft failure — keep last numbers |
| Other 4xx | Hard failure |
| Decode error | Treat as schema change — keep last numbers |

## Sanitized fixtures

See `fixtures/cursor/`. `usage_summary_ultra.json` is a real-shape Ultra payload with redacted identity. `usage_summary_mock.json` is a 68% / 42% demo used when `aiMeter.debug.useFixture` is true.

## Out of scope (v1)

- Reading `state.vscdb` or the Cursor Agent keychain from the extension host
- Billing-cycle history walk
- Daily spend fill
- Team Admin API
