import AIMeterCore

extension ProviderKind {
    var reconnectInstructions: String {
        switch self {
        case .cursor:
            return "Click Reconnect to sign in here, or use “Connect from Cursor IDE” above."
        case .claude:
            return "In Terminal run `claude`, enter `/login`, wait for “Login successful,” then click Reconnect."
        case .codex:
            return "AI Meter reads ~/.codex/auth.json. If `codex` is not installed, run `brew install --cask codex` (or `npm install -g @openai/codex`), then `codex login`, then click Reconnect."
        }
    }

    var reconnectProgressTitle: String {
        switch self {
        case .cursor:
            return "Signing in…"
        case .claude:
            return "Checking Claude Code session…"
        case .codex:
            return "Checking Codex session…"
        }
    }
}
