# Cursor Usage Tracker

<p align="center">
  <img src="docs/images/cursor-usage-tracker-logo-dark.png" width="128" alt="Cursor Usage Tracker">
</p>

A local-first usage meter for **Cursor Pro / Pro+ / Ultra**. Glance at Cursor Models %, Other Models %, spend, and on-demand without opening the Cursor dashboard.

- **macOS** menu bar extra + desktop widgets (no Dock icon by default)
- **iPhone** app + Home Screen widgets
- **Apple Watch** glance + complications (sanitized snapshot only — no tokens)

Current version: **0.3.0** · MIT · [LICENSE](LICENSE)

## What it does

Cursor Usage Tracker signs in with your personal Cursor session, pulls the same included-usage pools the dashboard shows, and keeps a live snapshot on this device.

| You see | Meaning |
|---------|---------|
| **Cursor Models %** | First-party / “auto” included pool |
| **Other Models %** | API / named-model included pool |
| **Total included %** | Overall included pool when Cursor reports it |
| **Subscription $** | Plan spend vs included limit (USD), plus bonus credits |
| **On-demand** | Enabled/disabled, billable usage, cap or unlimited |
| **Models this period** | Per-model spend and tokens for the billing cycle |
| **Days left** | Remaining days in the current billing window |

On Mac it can also show **Agents** — This Mac (editor), CLI (`cursor-agent`), and cloud runs (when you save a Cursor Cloud Agents API key).

It does **not** scrape the dashboard, store tokens in iCloud, or send credentials to Watch. Team / Enterprise Admin API is not implemented yet.

## Platforms

| Surface | What you get |
|---------|----------------|
| **macOS 14+** | Menu bar meter, click popover, Settings (8 tabs), desktop WidgetKit gallery |
| **iOS 17+** | Overview / Accounts / Settings tabs, swipe between accounts, Home Screen widgets |
| **watchOS 10+** | Companion glance + complications from the iPhone snapshot |

Shared logic lives in [`Packages/CursorUsageCore`](Packages/CursorUsageCore) so every surface reads the same `UsageSnapshot`.

## Sign in

1. **Sign in with Cursor** — in-app WebView; captures `WorkosCursorSessionToken`
2. **Connect from Cursor IDE** (Mac only) — prefers the IDE `state.vscdb` token, then Agent keychain `cursor-access-token`
3. **Paste token** — JWT or full cookie value

Tokens stay in the device Keychain. You can save multiple personal accounts, rename them, and switch which one is active. See [docs/FEATURES.md](docs/FEATURES.md#accounts--sign-in).

## Quick start

See **[docs/XCODE_SETUP.md](docs/XCODE_SETUP.md)**.

```bash
brew install xcodegen   # if needed
xcodegen generate
open CursorUsageTracker.xcodeproj
```

- Scheme **CursorUsageTracker** → My Mac (look in the menu bar, not the Dock)
- Scheme **CursorUsageiOS** → iPhone (Watch installs as the companion)

```bash
cd Packages/CursorUsageCore && swift test
```

## Docs

| Doc | Role |
|-----|------|
| [docs/FEATURES.md](docs/FEATURES.md) | Features, settings, metrics, widgets, alerts |
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | Architecture, data flow, auth, privacy |
| [docs/XCODE_SETUP.md](docs/XCODE_SETUP.md) | Build & run in Xcode |
| [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) | Notarize Mac; TestFlight iOS + Watch |
| [docs/api-spike-personal.md](docs/api-spike-personal.md) | Personal API mapping used by the client |
| [Apps/watchOS/README.md](Apps/watchOS/README.md) | Watch data path (no tokens) |
| [docs/cursor-usage-tracker-prd.md](docs/cursor-usage-tracker-prd.md) | Aspirational PRD — **not** the shipped product |
| [docs/archive/](docs/archive/) | Non-authoritative archived sketches |

Full index: [docs/README.md](docs/README.md).
