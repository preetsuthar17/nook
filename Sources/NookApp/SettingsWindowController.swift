import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
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
        window.makeKeyAndOrderFront(nil)
        // Defer activation to the next run loop tick so the popover
        // has time to close first; otherwise the close steals focus
        // and pushes this window to the background.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hide() {
        window?.orderOut(nil)
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
        window.title = "Nook Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 560, height: 380)
        return window
    }
}
