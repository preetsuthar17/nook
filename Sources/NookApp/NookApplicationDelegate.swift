import AppKit
@preconcurrency import Combine
import SwiftUI

@MainActor
final class NookApplicationDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var lastCloseDate: Date = .distantPast

    override init() {
        self.model = AppModel()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.configureAppIcon()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let pop = NSPopover()
        pop.behavior = .applicationDefined
        pop.animates = false
        pop.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                model: model,
                dismiss: { [weak self] in self?.closePopover() }
            )
        )
        popover = pop

        model.$appState
            .combineLatest(model.$launchPhase)
            .sink { [weak self] appState, launchPhase in
                let content = MenuBarLabelFormatter.content(
                    launchPhase: launchPhase,
                    state: appState
                )
                self?.updateStatusBarButton(content: content)
            }
            .store(in: &cancellables)

        model.handleAppDidFinishLaunching()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if Date().timeIntervalSince(lastCloseDate) < 0.25 { return }

        if popover.isShown {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    private func openPopover(relativeTo button: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installEventMonitor()
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        lastCloseDate = Date()
        removeEventMonitor()
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            if let button = self.statusItem.button,
               let buttonWindow = button.window
            {
                let localRect = button.convert(button.bounds, to: nil)
                let screenRect = buttonWindow.convertToScreen(localRect)
                let clickScreenPoint: NSPoint
                if let eventWindow = event.window {
                    clickScreenPoint = eventWindow.convertToScreen(
                        NSRect(origin: event.locationInWindow, size: .zero)
                    ).origin
                } else {
                    clickScreenPoint = event.locationInWindow
                }
                if screenRect.contains(clickScreenPoint) { return }
            }
            self.closePopover()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func updateStatusBarButton(content: MenuBarLabelContent) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: content.symbolName,
            accessibilityDescription: content.accessibilityLabel
        )
        if let countdown = content.countdownText {
            button.title = countdown
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    static func configureAppIcon(bundleURL: URL = Bundle.main.bundleURL) {
        guard shouldApplyRuntimeIcon(bundleURL: bundleURL),
              let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let iconImage = NSImage(contentsOf: iconURL)
        else {
            return
        }

        iconImage.size = NSSize(width: 128, height: 128)
        NSApplication.shared.applicationIconImage = iconImage
    }

    nonisolated static func shouldApplyRuntimeIcon(bundleURL: URL) -> Bool {
        bundleURL.pathExtension != "app"
    }
}
