import AppKit
import SwiftUI

/// The screen containing the mouse cursor, falling back to the main screen.
var activeScreen: NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
        ?? NSScreen.main
        ?? NSScreen.screens.first
        ?? NSScreen()
}

@MainActor
enum OverlayWindowHelper {
    static func makeFullscreenWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return window
    }

    static func presentOverlay<Content: View>(
        in window: NSWindow,
        rootView: Content,
        fadeDuration: TimeInterval = 0.5,
        timingFunction: CAMediaTimingFunctionName = .easeOut
    ) {
        let screenFrame = activeScreen.frame
        window.setFrame(screenFrame, display: true)

        let blurView = NSVisualEffectView(frame: screenFrame)
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.appearance = NSAppearance(named: .darkAqua)
        blurView.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]

        blurView.addSubview(hostingView)
        window.contentView = blurView
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            window.animator().alphaValue = 1
        }
    }

    static func dismissOverlay(_ window: NSWindow, fadeDuration: TimeInterval = 0.4) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                window.orderOut(nil)
            }
        })
    }
}
