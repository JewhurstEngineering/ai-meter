import AppKit

enum AppActivation {
    /// Menu bar (LSUIElement) apps often open Settings behind other apps unless activated.
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Call after SwiftUI `SettingsLink` / Settings scene opens — do **not** use
    /// `showSettingsWindow:` from a Button (SwiftUI warns; use `SettingsLink` instead).
    static func focusSettingsWindows() {
        bringToFront()
        let candidates = NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            let isPanel = window.styleMask.contains(.nonactivatingPanel) || window.level == .statusBar
            return window.styleMask.contains(.titled) && !isPanel
        }
        for window in candidates {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    static func scheduleSettingsFocus() {
        bringToFront()
        DispatchQueue.main.async {
            focusSettingsWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            focusSettingsWindows()
        }
    }

    /// Dock reopen / fallback when no SettingsLink is in the call path.
    static func openSettingsViaLinkFallback() {
        bringToFront()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        scheduleSettingsFocus()
    }
}
