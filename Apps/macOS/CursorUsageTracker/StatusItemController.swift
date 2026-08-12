import AppKit
import SwiftUI
import Combine
import CursorUsageCore

/// AppKit status item — SwiftUI `MenuBarExtra` labels get clipped/`…` truncated.
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var store: UsageStore?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func start(store: UsageStore) {
        self.store = store

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let hosting = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(store)
                .frame(width: 360)
        )
        // Opaque fill so vibrancy does not blend editor chrome into the UI.
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = hosting
        popover = pop

        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshTitle() }
            }
            .store(in: &cancellables)

        store.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)
        store.$preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prefs in
                self?.refreshTitle()
                self?.applyPopoverAppearance(prefs)
            }
            .store(in: &cancellables)
        store.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        refreshTitle()
        applyPopoverAppearance(store.preferences)
        Task { await store.bootstrap() }
    }

    private func applyPopoverAppearance(_ prefs: DisplayPreferences) {
        let appearance = prefs.appearanceMode.nsAppearance
        popover?.appearance = appearance
        let paint: () -> Void = { [weak self] in
            self?.popover?.contentViewController?.view.layer?.backgroundColor =
                NSColor.windowBackgroundColor.cgColor
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(paint)
        } else {
            paint()
        }
    }

    func refreshTitle() {
        guard let store, let button = statusItem?.button else { return }
        let presentation = store.menuBarPresentation
        button.image = Self.menuBarLogo()
        button.imagePosition = .imageLeft
        button.attributedTitle = Self.makeAttributedTitle(
            presentation: presentation,
            showText: store.preferences.showInMenuBar
        )
        button.toolTip = presentation.accessibilityTitle
    }

    func closePopover() {
        popover?.performClose(nil)
        removeEventMonitor()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            AppActivation.bringToFront()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Self.hardenPopoverBackground(popover)
            addEventMonitor()
        }
    }

    /// NSPopover wraps content in a vibrant effect view; force an opaque material so dark apps don't show through.
    private static func hardenPopoverBackground(_ popover: NSPopover) {
        guard let root = popover.contentViewController?.view else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        func walk(_ view: NSView) {
            if let effect = view as? NSVisualEffectView {
                effect.material = .contentBackground
                effect.blendingMode = .withinWindow
                effect.state = .active
                effect.isEmphasized = true
            }
            view.subviews.forEach(walk)
        }
        walk(root)
        if let frame = root.superview {
            walk(frame)
        }
    }

    private func addEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private static func makeAttributedTitle(
        presentation: MenuBarPresentation,
        showText: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.menuBarFont(ofSize: 0)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .baselineOffset: -0.5,
        ]
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
            .baselineOffset: -0.5,
        ]

        if showText {
            if !presentation.segments.isEmpty {
                result.append(NSAttributedString(string: " ", attributes: textAttrs))
            }
            for (index, segment) in presentation.segments.enumerated() {
                if index > 0 {
                    result.append(NSAttributedString(string: " · ", attributes: sepAttrs))
                }
                if let icon = segment.systemImage {
                    appendSymbol(named: icon, to: result, pointSize: 11)
                    result.append(NSAttributedString(string: "\(segment.text)", attributes: textAttrs))
                } else {
                    result.append(NSAttributedString(string: segment.text, attributes: textAttrs))
                }
            }
        }

        if presentation.showWarningDot {
            result.append(NSAttributedString(string: " ", attributes: textAttrs))
            let dot = NSMutableAttributedString(string: "●", attributes: [
                .font: NSFont.systemFont(ofSize: 7, weight: .bold),
                .foregroundColor: NSColor.systemRed,
                .baselineOffset: 1,
            ])
            result.append(dot)
        }

        return result
    }

    private static func menuBarLogo() -> NSImage? {
        guard let base = NSImage(named: "AppLogoTemplate") else { return nil }
        let point = NSSize(width: 18, height: 18)
        let image = NSImage(size: point, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            base.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func appendSymbol(named name: String, to result: NSMutableAttributedString, pointSize: CGFloat) {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let image = (base.withSymbolConfiguration(config) ?? base).copy() as? NSImage ?? base
        image.isTemplate = true
        image.size = NSSize(width: pointSize + 1, height: pointSize + 1)

        let attachment = NSTextAttachment()
        attachment.image = image
        // Nudge symbol to align with menu-bar text.
        let y = (NSFont.menuBarFont(ofSize: 0).capHeight - image.size.height) / 2
        attachment.bounds = CGRect(x: 0, y: y, width: image.size.width, height: image.size.height)
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.menuBarFont(ofSize: 0),
        ]))
    }
}
