# watchOS (Phase 2 scaffold)

Watch should **only** display sanitized `WidgetSnapshot` data synced from iPhone/Mac.

Do **not** put `WorkosCursorSessionToken` or JWTs on the watch.

Suggested next steps in Xcode:

1. File → New → Target → Watch App (`CursorUsageWatch`)
2. Link `CursorUsageCore`
3. Use WatchConnectivity to receive snapshot JSON from the iOS/macOS host
4. Add a circular complication showing Other Models % (or configurable metric)

Until that target exists, macOS menu bar + desktop widget are the supported glance surfaces.
