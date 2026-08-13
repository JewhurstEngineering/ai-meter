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

    private static let popoverSize = NSSize(width: 360, height: 580)

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
        )
        hosting.sizingOptions = []
        hosting.preferredContentSize = Self.popoverSize
        hosting.view.wantsLayer = true

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = Self.popoverSize
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
                WindowAppearanceApplier.apply(prefs.appearanceMode.nsAppearance)
            }
            .store(in: &cancellables)
        store.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        SystemAppearanceMonitor.shared.$isDark
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let prefs = self.store?.preferences else { return }
                self.applyPopoverAppearance(prefs)
            }
            .store(in: &cancellables)

        refreshTitle()
        applyPopoverAppearance(store.preferences)
        Task { await store.bootstrap() }
    }

    private func applyPopoverAppearance(_ prefs: DisplayPreferences) {
        let appearance = prefs.appearanceMode.nsAppearance ?? NSApp.effectiveAppearance
        popover?.appearance = appearance
        if let view = popover?.contentViewController?.view {
            view.appearance = appearance
            appearance.performAsCurrentDrawingAppearance {
                view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
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
            if let store {
                applyPopoverAppearance(store.preferences)
            }
            popover.contentSize = Self.popoverSize
            popover.contentViewController?.preferredContentSize = Self.popoverSize
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Self.hardenPopoverBackground(popover)
            addEventMonitor()
        }
    }

    /// NSPopover wraps content in a vibrant effect view; force an opaque material so dark apps don't show through.
    private static func hardenPopoverBackground(_ popover: NSPopover) {
        guard let root = popover.contentViewController?.view else { return }
        let appearance = popover.appearance ?? NSApp.effectiveAppearance
        root.wantsLayer = true
        appearance.performAsCurrentDrawingAppearance {
            root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }

        func walk(_ view: NSView) {
            view.appearance = appearance
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
            appendSymbol(
                named: "exclamationmark.triangle.fill",
                to: result,
                pointSize: 11,
                color: .systemOrange,
                trailingSpace: false
            )
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

    private static func appendSymbol(
        named name: String,
        to result: NSMutableAttributedString,
        pointSize: CGFloat,
        color: NSColor? = nil,
        trailingSpace: Bool = true
    ) {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let sized = NSImage.SymbolConfiguration(pointSize: pointSize, weight: color == nil ? .medium : .semibold)
        let config: NSImage.SymbolConfiguration
        if let color {
            config = sized.applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        } else {
            config = sized
        }
        let image = (base.withSymbolConfiguration(config) ?? base).copy() as? NSImage ?? base
        image.isTemplate = color == nil
        image.size = NSSize(width: pointSize + 1, height: pointSize + 1)

        let attachment = NSTextAttachment()
        attachment.image = image
        let y = (NSFont.menuBarFont(ofSize: 0).capHeight - image.size.height) / 2
        attachment.bounds = CGRect(x: 0, y: y, width: image.size.width, height: image.size.height)
        result.append(NSAttributedString(attachment: attachment))
        if trailingSpace {
            result.append(NSAttributedString(string: " ", attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
            ]))
        }
    }
}
