import AppKit
import SwiftUI
import AIMeterCore
#if !DEBUG
import Sparkle
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()
    private let statusItem = StatusItemController()
#if !DEBUG
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.onWidgetSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        AppInstall.registerEmbeddedWidget()
        installAppMenu()
        statusItem.start(store: store)
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                AppActivation.openSettingsViaLinkFallback()
            }
        }
        return true
    }

#if !DEBUG
    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }
#endif

    @objc func showAbout(_ sender: Any?) {
        AppActivation.openSettingsViaLinkFallback()
    }

    @objc func showSettings(_ sender: Any?) {
        AppActivation.openSettingsViaLinkFallback()
    }

    private func installAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let about = NSMenuItem(
            title: "About AI Meter",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        about.target = self
        appMenu.addItem(about)
#if !DEBUG
        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        appMenu.addItem(checkForUpdates)
#endif
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit AI Meter",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}

@main
struct AIMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar UI is hosted by StatusItemController (AppKit) so the label
        // is not clipped the way SwiftUI MenuBarExtra truncates with "…".
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
