# JamesWare AI Meter

<p align="center">
  <img src="docs/images/cursor-usage-tracker-logo-dark.png" width="128" alt="AI Meter">
</p>

A local-first usage meter for **Cursor**, **Claude Code**, and **Codex**. Glance at included pools, rolling windows, spend, and on-demand without opening each dashboard.

- **macOS** menu bar extra + desktop widgets (no Dock icon by default)
- **iPhone** app + Home Screen widgets (Cursor snapshot in this version)
- **Apple Watch** glance + complications (sanitized snapshot only — no tokens)

Current version: **0.3.1** · MIT · [LICENSE](LICENSE)

## What it does

AI Meter signs in with your local sessions, pulls the same usage the products already show, and keeps a live snapshot on this device.

| You see | Cursor | Claude / Codex |
|---------|--------|----------------|
| **Cursor / Other / Total %** | Included pools this billing period | — |
| **Session / Weekly %** | — | 5-hour and 7-day rolling windows |
| **Subscription $ / on-demand** | Plan spend vs included + on-demand | Extra usage or credits when present |
| **Models this period** | Per-model spend and tokens | — |
| **Spend by cycle / pace** | Billing windows | Reset countdown instead |
| **Agents** | This Mac / CLI / Cloud | — |

It does **not** scrape dashboards, store tokens in iCloud, or send credentials to Watch. ChatGPT chat message caps and Team / Enterprise Admin APIs are not implemented.

## Platforms

| Surface | What you get |
|---------|----------------|
| **macOS 14+** | Menu bar meter, click popover, Settings, desktop WidgetKit gallery |
| **iOS 17+** | Overview / Accounts / Settings tabs, swipe between accounts, Home Screen widgets |
| **watchOS 10+** | Companion glance + complications from the iPhone snapshot |

Shared logic lives in [`Packages/AIMeterCore`](Packages/AIMeterCore) so every surface reads the same `UsageSnapshot`.

## Sign in

1. **Sign in with Cursor** — in-app WebView; captures `WorkosCursorSessionToken`
2. **Connect from Cursor IDE** (Mac only) — prefers the IDE `state.vscdb` token, then Agent keychain `cursor-access-token`
3. **Add Claude Code** (Mac only) — Claude Code keychain or `~/.claude/.credentials.json`
4. **Add Codex** (Mac only) — `~/.codex/auth.json`
5. **Paste token** — Cursor JWT or full cookie value

Tokens stay in the device Keychain. You can save multiple accounts (mixed providers), rename them, and show them **Active**, **Combined**, or **Separate** in the menu bar. See [docs/FEATURES.md](docs/FEATURES.md#accounts--sign-in).

## Quick start

See **[docs/XCODE_SETUP.md](docs/XCODE_SETUP.md)**.

```bash
brew install xcodegen   # if needed
xcodegen generate
open AIMeter.xcodeproj
```

- Scheme **AIMeter** → My Mac (look in the menu bar, not the Dock)
- Scheme **AIMeteriOS** → iPhone (Watch installs as the companion)

```bash
cd Packages/AIMeterCore && swift test
```

## Docs

| Doc | Role |
|-----|------|
| [docs/FEATURES.md](docs/FEATURES.md) | Features, settings, metrics, widgets, alerts |
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | Architecture, data flow, auth, privacy |
| [docs/XCODE_SETUP.md](docs/XCODE_SETUP.md) | Build & run in Xcode |
| [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) | Notarize Mac; TestFlight iOS + Watch |
| [docs/api-spike-personal.md](docs/api-spike-personal.md) | Cursor personal API mapping |
| [docs/api-spike-claude.md](docs/api-spike-claude.md) | Claude Code OAuth usage mapping |
| [docs/api-spike-codex.md](docs/api-spike-codex.md) | Codex / ChatGPT usage mapping |
| [Apps/watchOS/README.md](Apps/watchOS/README.md) | Watch data path (no tokens) |
| [docs/cursor-usage-tracker-prd.md](docs/cursor-usage-tracker-prd.md) | Aspirational PRD — **not** the shipped product |
| [docs/archive/](docs/archive/) | Non-authoritative archived sketches |

Full index: [docs/README.md](docs/README.md).
