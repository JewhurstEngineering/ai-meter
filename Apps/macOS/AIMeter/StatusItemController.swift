import AppKit
import SwiftUI
import Combine
import AIMeterCore

/// AppKit status item — SwiftUI `MenuBarExtra` labels get clipped/`…` truncated.
@MainActor
final class StatusItemController: NSObject {
    private enum SlotKey: Hashable {
        case single
        case account(UUID)
    }

    private struct Slot {
        var item: NSStatusItem
        var popover: NSPopover
        var hosting: NSHostingController<AnyView>
        var accountID: UUID?
    }

    private var slots: [SlotKey: Slot] = [:]
    private var store: UsageStore?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var lastLayoutSignature = ""
    private var idealHeights: [SlotKey: CGFloat] = [:]

    private var popoverWidth: CGFloat {
        store?.preferences.interfaceSize.popoverWidth ?? 360
    }

    private func syncPopoverSize(_ popover: NSPopover?, hosting: NSHostingController<AnyView>?) {
        guard let hosting else { return }
        let width = popoverWidth
        let screenCap = (NSScreen.main?.visibleFrame.height ?? 900) * 0.72
        let key = slots.first { $0.value.hosting === hosting }?.key
        let fitted: CGFloat
        if let key, let measured = idealHeights[key], measured > 1 {
            fitted = measured
        } else {
            hosting.sizingOptions = [.intrinsicContentSize]
            hosting.view.layoutSubtreeIfNeeded()
            fitted = hosting.sizeThatFits(
                in: CGSize(width: width, height: screenCap)
            ).height
        }
        applyPopoverContentSize(popover, hosting: hosting, height: fitted, screenCap: screenCap, width: width)
    }

    private func applyMeasuredPopoverHeight(_ height: CGFloat, accountID: UUID?) {
        let key: SlotKey = accountID.map { .account($0) } ?? .single
        idealHeights[key] = height
        guard let slot = slots[key] else { return }
        let screenCap = (NSScreen.main?.visibleFrame.height ?? 900) * 0.72
        applyPopoverContentSize(
            slot.popover,
            hosting: slot.hosting,
            height: height,
            screenCap: screenCap,
            width: popoverWidth
        )
    }

    private func applyPopoverContentSize(
        _ popover: NSPopover?,
        hosting: NSHostingController<AnyView>,
        height: CGFloat,
        screenCap: CGFloat,
        width: CGFloat
    ) {
        let capped = min(max(height.rounded(.up), 1), screenCap)
        let size = NSSize(width: width, height: capped)
        if abs((popover?.contentSize.height ?? 0) - capped) < 0.5,
           abs((popover?.contentSize.width ?? 0) - width) < 0.5 {
            return
        }
        hosting.sizingOptions = height > screenCap + 0.5 ? [] : [.intrinsicContentSize]
        hosting.preferredContentSize = size
        popover?.contentSize = size
    }

    func start(store: UsageStore) {
        self.store = store
        rebuildSlotsIfNeeded()

        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuildSlotsIfNeeded()
                    self?.refreshTitles()
                }
            }
            .store(in: &cancellables)

        store.$runtimes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTitles()
                self?.syncShownPopovers()
            }
            .store(in: &cancellables)
        store.$activeAccountID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTitles() }
            .store(in: &cancellables)
        store.$preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prefs in
                self?.rebuildSlotsIfNeeded()
                self?.refreshTitles()
                self?.applyAllPopoverAppearances(prefs)
                WindowAppearanceApplier.apply(prefs.appearanceMode.nsAppearance)
                self?.syncAllPopoverSizes()
            }
            .store(in: &cancellables)
        store.$connections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildSlotsIfNeeded()
                self?.refreshTitles()
            }
            .store(in: &cancellables)

        SystemAppearanceMonitor.shared.$isDark
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let prefs = self.store?.preferences else { return }
                self.applyAllPopoverAppearances(prefs)
            }
            .store(in: &cancellables)

        refreshTitles()
        Task { await store.bootstrap() }
    }

    private func layoutSignature(store: UsageStore) -> String {
        let ids = store.connections.map(\.id.uuidString).joined(separator: ",")
        return "\(store.preferences.menuBarAccountMode.rawValue)|\(ids)"
    }

    private func rebuildSlotsIfNeeded() {
        guard let store else { return }
        let signature = layoutSignature(store: store)
        guard signature != lastLayoutSignature else { return }
        lastLayoutSignature = signature

        let mode = store.preferences.menuBarAccountMode
        let desired: [SlotKey]
        switch mode {
        case .activeOnly, .combined:
            desired = [.single]
        case .separateItems:
            if store.connections.isEmpty {
                desired = [.single]
            } else {
                desired = store.connections.map { .account($0.id) }
            }
        }

        let desiredSet = Set(desired)
        for (key, slot) in slots where !desiredSet.contains(key) {
            slot.popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(slot.item)
            slots[key] = nil
        }

        for key in desired where slots[key] == nil {
            let accountID: UUID?
            switch key {
            case .single: accountID = nil
            case .account(let id): accountID = id
            }
            slots[key] = makeSlot(store: store, accountID: accountID)
        }

        applyAllPopoverAppearances(store.preferences)
        refreshTitles()
    }

    private func makeSlot(store: UsageStore, accountID: UUID?) -> Slot {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let hosting = NSHostingController(
            rootView: AnyView(
                MenuBarPopoverView(
                    focusedAccountID: accountID,
                    onIdealHeight: { [weak self] height in
                        self?.applyMeasuredPopoverHeight(height, accountID: accountID)
                    }
                )
                .environmentObject(store)
            )
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.view.wantsLayer = true

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = false
        pop.contentViewController = hosting
        syncPopoverSize(pop, hosting: hosting)

        return Slot(item: item, popover: pop, hosting: hosting, accountID: accountID)
    }

    private func applyAllPopoverAppearances(_ prefs: DisplayPreferences) {
        for slot in slots.values {
            applyPopoverAppearance(slot.popover, prefs: prefs)
        }
    }

    private func applyPopoverAppearance(_ popover: NSPopover, prefs: DisplayPreferences) {
        let appearance = prefs.appearanceMode.nsAppearance ?? NSApp.effectiveAppearance
        popover.appearance = appearance
        if let view = popover.contentViewController?.view {
            view.appearance = appearance
            appearance.performAsCurrentDrawingAppearance {
                view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }
    }

    func refreshTitles() {
        guard let store else { return }
        for (key, slot) in slots {
            guard let button = slot.item.button else { continue }
            let presentation: MenuBarPresentation
            switch key {
            case .single:
                presentation = store.menuBarPresentation
            case .account(let id):
                presentation = store.menuBarPresentation(for: id)
            }
            button.image = Self.menuBarLogo()
            button.imagePosition = .imageLeft
            button.attributedTitle = Self.makeAttributedTitle(
                presentation: presentation,
                showText: store.preferences.showInMenuBar
            )
            button.toolTip = presentation.accessibilityTitle
        }
    }

    private func syncAllPopoverSizes() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for slot in self.slots.values {
                self.syncPopoverSize(slot.popover, hosting: slot.hosting)
            }
        }
    }

    private func syncShownPopovers() {
        for slot in slots.values where slot.popover.isShown {
            syncPopoverSize(slot.popover, hosting: slot.hosting)
        }
    }

    func closePopover() {
        for slot in slots.values {
            slot.popover.performClose(nil)
        }
        removeEventMonitor()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let store else { return }
        let button = sender as? NSStatusBarButton
        let slot = slots.values.first { $0.item.button === button } ?? slots[.single]
        guard let slot, let button = slot.item.button else { return }

        if slot.popover.isShown {
            closePopover()
            return
        }

        closePopover()
        AppActivation.bringToFront()
        applyPopoverAppearance(slot.popover, prefs: store.preferences)
        syncPopoverSize(slot.popover, hosting: slot.hosting)
        // Attach below the item with a little gap so the rounded top isn’t under the menu bar.
        var rect = button.bounds
        rect.origin.y -= 6
        slot.popover.show(relativeTo: rect, of: button, preferredEdge: .minY)
        Self.hardenPopoverBackground(slot.popover)
        syncPopoverSize(slot.popover, hosting: slot.hosting)
        DispatchQueue.main.async { [weak self] in
            self?.syncPopoverSize(slot.popover, hosting: slot.hosting)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.syncPopoverSize(slot.popover, hosting: slot.hosting)
        }
        addEventMonitor()
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
        let y = (NSFont.menuBarFont(ofSize: 0).capHeight - image.size.height) / 2
        attachment.bounds = CGRect(x: 0, y: y, width: image.size.width, height: image.size.height)
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.menuBarFont(ofSize: 0),
        ]))
    }
}
