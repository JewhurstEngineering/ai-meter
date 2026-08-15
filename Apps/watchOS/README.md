# watchOS

Companion to the **iPhone** app (`com.jamesware.aimeter.ios`). WatchConnectivity pushes a sanitized `WidgetSnapshot` only. Feature overview: [docs/FEATURES.md](../../docs/FEATURES.md#apple-watch). Data path detail: [docs/HOW_IT_WORKS.md](../../docs/HOW_IT_WORKS.md#widgets--watch).

**Do not** put `WorkosCursorSessionToken` or JWTs on the Watch.

## What it shows

- Glance: plan name, Other Models %, Cursor / Total, spend, days left, top model, age of the snapshot
- Complications (WidgetKit): circular, rectangular, inline, corner — Other Models % from the Watch App Group cache

## Data path

```text
iPhone UsageStore
  → WidgetSnapshotStore (group.com.jamesware.aimeter.shared)
  → PhoneWatchBridge.updateApplicationContext
  → WatchSessionBridge
  → WidgetSnapshotStore.writeWatchLocal (group.com.jamesware.aimeter.watch)
  → Watch UI + complications
```

Tokens stay in the iPhone Keychain. The Watch group holds JSON usage only.

## Run

1. `xcodegen generate`
2. Scheme **AIMeteriOS** → iPhone (paired Watch or simulator Watch)
3. Sign in on iPhone; open the Watch app once so `WCSession` activates
4. Add the **AI Meter** complication from the Watch face editor
