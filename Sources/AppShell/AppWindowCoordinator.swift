import AppKit
import Core
import SwiftUI

@MainActor
final class AppWindowCoordinator: WindowCoordinator {
    private weak var model: AppModel?
    private let onboardingFlowController: OnboardingFlowWindowController
    private let breakOverlayController: BreakOverlayWindowController
    private let breakReminderController: ReminderPanelController
    private let wellnessReminderController: WellnessPanelController
    private let contextualHintController = ContextualHintController()
    private(set) var currentBreakReminderDate: Date?
    private(set) var currentBreakOverlaySessionID: UUID?

    init(
        model: AppModel,
        onboardingFlowController: OnboardingFlowWindowController,
        breakOverlayController: BreakOverlayWindowController,
        breakReminderController: ReminderPanelController,
        wellnessReminderController: WellnessPanelController
        ) {
        self.model = model
        self.onboardingFlowController = onboardingFlowController
        self.breakOverlayController = breakOverlayController
        self.breakReminderController = breakReminderController
        self.wellnessReminderController = wellnessReminderController
    }

    func show(_ route: WindowRoute) {
        switch route {
        case .onboardingFlow:
            showOnboardingFlow()
        case .settings:
            break
        case .breakReminder:
            guard !onboardingFlowController.isVisible,
                  let nextBreakDate = model?.appState.nextBreakDate
            else { return }
            contextualHintController.hide()
            wellnessReminderController.hide()
            breakReminderController.show(nextBreakDate: nextBreakDate)
        case let .wellnessReminder(kind):
            guard !onboardingFlowController.isVisible,
                  model?.appState.activeBreak == nil,
                  let event = model?.pendingWellnessEvent,
                  event.kind == kind
            else { return }
            breakReminderController.hide()
            contextualHintController.hide()
            wellnessReminderController.show(event: event)
        case let .contextualHint(kind):
            guard !onboardingFlowController.isVisible else { return }
            if model?.pendingWellnessEvent != nil {
                wellnessReminderController.hide()
            }
            contextualHintController.show(kind: kind)
        case let .breakOverlay(session):
            guard !onboardingFlowController.isVisible else { return }
            breakReminderController.hide()
            wellnessReminderController.hide()
            contextualHintController.hide()
            breakOverlayController.show(session: session)
        }
    }

    func hide(_ route: WindowRoute) {
        switch route {
        case .onboardingFlow:
            onboardingFlowController.hide()
        case .settings:
            break
        case .breakReminder:
            breakReminderController.hide()
        case .wellnessReminder:
            wellnessReminderController.hide()
        case .contextualHint:
            contextualHintController.hide()
        case .breakOverlay:
            breakOverlayController.hide()
        }
    }

    func hideAllTransientWindows() {
        breakReminderController.hide()
        wellnessReminderController.hide()
        contextualHintController.hide()
        breakOverlayController.hide()
        currentBreakReminderDate = nil
        currentBreakOverlaySessionID = nil
    }

    func isVisible(_ route: WindowRoute) -> Bool {
        switch route {
        case .onboardingFlow:
            onboardingFlowController.isVisible
        case .settings:
            false
        case .breakReminder:
            false
        case .wellnessReminder:
            wellnessReminderController.isVisible
        case .contextualHint:
            contextualHintController.isVisible
        case .breakOverlay:
            false
        }
    }

    func showBreakReminder(nextBreakDate: Date) {
        guard !onboardingFlowController.isVisible else { return }
        contextualHintController.hide()
        wellnessReminderController.hide()
        breakReminderController.show(nextBreakDate: nextBreakDate)
        currentBreakReminderDate = nextBreakDate
    }

    func hideBreakReminder() {
        breakReminderController.hide()
        currentBreakReminderDate = nil
    }

    var isBreakReminderVisible: Bool {
        breakReminderController.isVisible
    }

    func showBreakOverlay(session: BreakSession) {
        guard !onboardingFlowController.isVisible else { return }
        breakReminderController.hide()
        currentBreakReminderDate = nil
        wellnessReminderController.hide()
        contextualHintController.hide()
        breakOverlayController.show(session: session)
        currentBreakOverlaySessionID = session.id
    }

    func hideBreakOverlay() {
        breakOverlayController.hide()
        currentBreakOverlaySessionID = nil
    }

    var isBreakOverlayVisible: Bool {
        breakOverlayController.isVisible
    }

    private func showOnboardingFlow() {
        hideAllTransientWindows()
        onboardingFlowController.show { [weak self] workInterval, breakDuration in
            self?.model?.finishOnboardingFlow(
                workInterval: workInterval,
                breakDuration: breakDuration
            )
        }
    }
}

@MainActor
final class ContextualHintController {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(kind: HintKind) {
        hideTask?.cancel()
        let panel = panel ?? makePanel()
        let screen = activeScreen.visibleFrame
        let margin: CGFloat = 20
        panel.setFrameOrigin(NSPoint(
            x: screen.maxX - panel.frame.width - margin,
            y: screen.maxY - panel.frame.height - margin
        ))
        panel.contentView = NSHostingView(rootView: ContextualHintView(kind: kind))
        panel.orderFrontRegardless()
        self.panel = panel
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 140),
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

private struct ContextualHintView: View {
    let kind: HintKind

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.symbolName)
                .font(.headline)
            Text(kind.body)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(8)
    }
}
