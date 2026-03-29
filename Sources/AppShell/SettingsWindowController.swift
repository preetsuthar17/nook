import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show(model: AppModel) {
        let window = window ?? makeWindow(model: model)
        self.window = window
        if !isVisible {
            window.center()
        }

        // Temporarily become a regular app so the window can hold focus
        // and appear in the dock / Cmd-Tab switcher.
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        revertToAccessory()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            revertToAccessory()
        }
    }

    // MARK: - Private

    private func revertToAccessory() {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let settingsView = SettingsView(model: model)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "nook Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 560, height: 380)
        window.delegate = self
        return window
    }
}
