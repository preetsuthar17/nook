import AppKit
import Core
import SwiftUI

@MainActor
final class BreakOverlayWindowController {
    private var window: NSWindow?
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    func show(session: BreakSession) {
        let window = window ?? OverlayWindowHelper.makeFullscreenWindow()
        self.window = window
        OverlayWindowHelper.presentOverlay(
            in: window,
            rootView: BreakOverlayView(model: model, session: session),
            fadeDuration: 0.5,
            timingFunction: .easeOut
        )
    }

    func hide() {
        guard let window else { return }
        OverlayWindowHelper.dismissOverlay(window)
    }

    var isVisible: Bool {
        window?.isVisible == true
    }
}
