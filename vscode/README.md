# AI Meter

A Cursor / VS Code extension that shows AI usage in the status bar.

> See your Cursor AI usage, spend, and reset date without leaving your editor.

This is the editor client of AI Meter, built by Jewhurst Engineering. The macOS, iPhone, and Watch apps live at the root of this repo. The extension is its own TypeScript project under `vscode/` and does not import the Swift package. Install the VSIX on its own. It is not inside the Mac download.

## What it shows

- Glanceable status bar: `AI 68%`
- Cursor Models, Other Models, and Grok Bot when the plan includes that weekly allowance
- On-demand spend when Cursor reports it
- Billing-cycle reset date
- Configurable warning / critical thresholds

Usage snapshots stay on this machine. No account is required.

## Install (local)

```bash
npm install
npm test
npm run package
```

That writes `dist/ai-meter.vsix`. In Cursor or VS Code: **Extensions → … → Install from VSIX…**

Or press **F5** in this folder to launch an Extension Development Host.

To try the meter without a Cursor session, set `aiMeter.debug.useFixture` to `true` (status bar shows `AI 68%` from bundled fixtures).

## Commands

- **AI Meter: Use This Cursor Login** — read the session already on this Mac
- **AI Meter: Paste Token** — escape hatch
- **AI Meter: Refresh Usage**
- **AI Meter: Disconnect Cursor**
- **AI Meter: Open Cursor Usage Dashboard**
- **AI Meter: Copy Usage Summary**
- **AI Meter: Diagnostics** — sanitized log, no tokens

Cursor transport details are in [`docs/cursor-data-source.md`](docs/cursor-data-source.md).

## Sign in

Click **AI — Sign In** or **Use this Cursor login**. The extension reads the session Cursor already stored on this Mac (same source as the menu-bar app’s “Connect from Cursor IDE”).

If that fails, **AI Meter: Paste Token** is the escape hatch. Tokens stay in Secret Storage, not settings.

## Privacy

Local-first. The extension reads billing/usage metadata only. It does not inspect source code, prompts, or chats.

AI Meter is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Anysphere or Cursor.

## License

[MIT](LICENSE)
