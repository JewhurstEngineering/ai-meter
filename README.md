# Cursor Usage Tracker

<p align="center">
  <img src="docs/images/cursor-usage-tracker-logo-dark.png" width="128" alt="Cursor Usage Tracker">
</p>

Local-first macOS menu bar meter for **Cursor Pro / Pro+ / Ultra** usage.

- Cursor Models % vs Other Models % (and on-demand state)
- Configurable auto-refresh
- WebView login, local Cursor session auto-connect, or paste token
- Desktop widgets: gallery presets (Cursor, Other, Total, On-demand, Rotate) plus a small/medium/large overview
- Multiple personal Cursor accounts (switcher, combined menu bar, or separate items)
- Light / dark lock plus choosable color themes (Original, Cursor, editor palettes, custom)
- Accessibility: interface size, color-vision palettes, patterns, high contrast
- Shared `CursorUsageCore` ready for iOS widgets + watchOS later

## Quick start

See **[docs/XCODE_SETUP.md](docs/XCODE_SETUP.md)**.

```bash
xcodegen generate
open CursorUsageTracker.xcodeproj
```

## Docs

| Doc | Role |
|-----|------|
| [docs/XCODE_SETUP.md](docs/XCODE_SETUP.md) | Build & run in Xcode |
| [docs/api-spike-personal.md](docs/api-spike-personal.md) | Personal API mapping |
| [docs/cursor-usage-tracker-prd.md](docs/cursor-usage-tracker-prd.md) | Reference library only |
| [docs/archive/](docs/archive/) | Non-authoritative archived sketches |

## License

MIT — see [LICENSE](LICENSE).

## Version

Current: **0.2.8**

