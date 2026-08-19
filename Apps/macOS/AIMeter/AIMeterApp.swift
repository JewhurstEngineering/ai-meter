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
    /// Started in `applicationDidFinishLaunching` so `self` can be the user-driver
    /// delegate (Sparkle holds that reference weakly).
    private(set) lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.onWidgetSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        AppInstall.registerEmbeddedWidget()
        installAppMenu()
        statusItem.start(store: store)
#if !DEBUG
        updaterController.startUpdater()
#endif
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
        presentSparkleUI()
        updaterController.checkForUpdates(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates(_:)) {
            return updaterController.updater.canCheckForUpdates
        }
        return true
    }

    /// Menu bar extras hide Sparkle windows unless the app is a regular, active app.
    func presentSparkleUI() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
        // Target AppDelegate (not the updater controller) so we can activate
        // the menu bar extra before Sparkle shows its checking window.
        // `validateMenuItem` still consults `canCheckForUpdates`.
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

#if !DEBUG
extension AppDelegate: SPUStandardUserDriverDelegate {
    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        presentSparkleUI()
    }

    func standardUserDriverWillShowModalAlert() {
        presentSparkleUI()
    }

    func standardUserDriverWillFinishUpdateSession() {
        NSApp.setActivationPolicy(.accessory)
    }
}
#endif

@main
struct AIMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar UI is hosted by StatusItemController (AppKit) so the label
        // is not clipped the way SwiftUI MenuBarExtra truncates with "…".
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
#if !DEBUG
                .environment(\.checkForUpdates, CheckForUpdatesAction {
                    appDelegate.checkForUpdates(nil)
                })
#endif
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
