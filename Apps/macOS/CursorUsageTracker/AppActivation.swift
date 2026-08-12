import AppKit

enum AppActivation {
    /// Menu bar (LSUIElement) apps often open Settings behind other apps unless activated.
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }

    static func openSettingsAndFocus() {
        bringToFront()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        DispatchQueue.main.async {
            focusSettingsWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            focusSettingsWindows()
        }
    }

    static func focusSettingsWindows() {
        bringToFront()
        let candidates = NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            // Settings scenes are titled windows that aren't the menu-bar panel.
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
}
