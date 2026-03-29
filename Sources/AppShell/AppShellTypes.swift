import Foundation
import Core

public enum AppLaunchPhase: String, Sendable {
    case onboarding
    case ready
}

public enum MenuBarMode: String, Sendable {
    case setup
    case active
}

public enum WindowRoute: Hashable, Sendable {
    case onboardingFlow
    case settings
    case breakReminder
    case wellnessReminder(WellnessReminderKind)
    case contextualHint(HintKind)
    case breakOverlay(BreakSession)
}

@MainActor
public protocol WindowCoordinator: AnyObject {
    func show(_ route: WindowRoute)
    func hide(_ route: WindowRoute)
    func hideAllTransientWindows()
    func isVisible(_ route: WindowRoute) -> Bool
    func showBreakReminder(nextBreakDate: Date)
    func hideBreakReminder()
    var isBreakReminderVisible: Bool { get }
    var currentBreakReminderDate: Date? { get }
    func showBreakOverlay(session: BreakSession)
    func hideBreakOverlay()
    var isBreakOverlayVisible: Bool { get }
    var currentBreakOverlaySessionID: UUID? { get }
}
