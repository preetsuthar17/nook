import AppKit
import Core
import SwiftUI

@MainActor
final class WellnessPanelController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(event: WellnessReminderEvent) {
        dismissTask?.cancel()

        let panel = panel ?? makePanel()
        let screen = activeScreen.visibleFrame
        let margin: CGFloat = 20
        panel.setFrameOrigin(NSPoint(
            x: screen.maxX - panel.frame.width - margin,
            y: screen.maxY - panel.frame.height - margin
        ))
        panel.contentView = NSHostingView(rootView: WellnessPanelView(event: event))
        panel.orderFrontRegardless()
        self.panel = panel

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.hide()
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        return panel
    }
}

private struct WellnessPanelView: View {
    let event: WellnessReminderEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(event.title, systemImage: event.kind == .posture ? "figure.seated.side" : "eye")
                .font(.headline)
            Text(event.body)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(8)
    }
}
