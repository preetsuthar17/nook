import Foundation
import Core
@testable import AppShell
import XCTest

@MainActor
final class AppModelTimerTests: XCTestCase {
    private struct MockActivityMonitor: ActivityMonitoring {
        var idleSeconds: TimeInterval
    }

    private final class MockWindowCoordinator: WindowCoordinator {
        var onboardingVisible = false
        var showBreakReminderCalls = 0
        var hideBreakReminderCalls = 0
        var showBreakOverlayCalls = 0
        var hideBreakOverlayCalls = 0
        var isBreakReminderVisible = false
        var isBreakOverlayVisible = false
        var currentBreakReminderDate: Date?
        var currentBreakOverlaySessionID: UUID?
        var shownBreakReminderDates: [Date] = []
        var shownBreakOverlaySessions: [BreakSession] = []

        func show(_ route: WindowRoute) {
            switch route {
            case .onboardingFlow:
                onboardingVisible = true
            case .breakReminder:
                isBreakReminderVisible = true
            case .breakOverlay:
                isBreakOverlayVisible = true
            default:
                break
            }
        }

        func hide(_ route: WindowRoute) {
            switch route {
            case .onboardingFlow:
                onboardingVisible = false
            case .breakReminder:
                isBreakReminderVisible = false
                currentBreakReminderDate = nil
            case .breakOverlay:
                isBreakOverlayVisible = false
                currentBreakOverlaySessionID = nil
            default:
                break
            }
        }

        func hideAllTransientWindows() {
            isBreakReminderVisible = false
            isBreakOverlayVisible = false
            currentBreakReminderDate = nil
            currentBreakOverlaySessionID = nil
        }

        func isVisible(_ route: WindowRoute) -> Bool {
            switch route {
            case .onboardingFlow:
                onboardingVisible
            case .breakReminder:
                isBreakReminderVisible
            case .breakOverlay:
                isBreakOverlayVisible
            default:
                false
            }
        }

        func showBreakReminder(nextBreakDate: Date) {
            showBreakReminderCalls += 1
            isBreakReminderVisible = true
            currentBreakReminderDate = nextBreakDate
            shownBreakReminderDates.append(nextBreakDate)
        }

        func hideBreakReminder() {
            hideBreakReminderCalls += 1
            isBreakReminderVisible = false
            currentBreakReminderDate = nil
        }

        func showBreakOverlay(session: BreakSession) {
            showBreakOverlayCalls += 1
            isBreakOverlayVisible = true
            currentBreakOverlaySessionID = session.id
            shownBreakOverlaySessions.append(session)
        }

        func hideBreakOverlay() {
            hideBreakOverlayCalls += 1
            isBreakOverlayVisible = false
            currentBreakOverlaySessionID = nil
        }
    }

    func testWorkPhaseCountdownDecreasesEveryTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 120,
            breakDuration: 20,
            reminderLeadTime: 0,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        XCTAssertEqual(model.appState.timerPhase, .work)
        XCTAssertEqual(model.appState.countdownText, "02:00")

        model.tick(now: start.addingTimeInterval(1))
        XCTAssertEqual(model.appState.countdownText, "01:59")
    }

    func testBreakPhaseCountdownDecreasesEveryTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            reminderLeadTime: 0,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))

        XCTAssertEqual(model.appState.timerPhase, .breakTime)
        XCTAssertEqual(model.appState.countdownText, "00:20")

        model.tick(now: start.addingTimeInterval(61))
        XCTAssertEqual(model.appState.countdownText, "00:19")
    }

    func testWorkCompletionShowsBreakOverlayFromState() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            reminderLeadTime: 0,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))

        XCTAssertNotNil(model.appState.activeBreak)
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 1)
        XCTAssertTrue(coordinator.isBreakOverlayVisible)
    }

    func testHiddenBreakOverlayIsShownAgainOnNextTick() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            reminderLeadTime: 0,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))
        coordinator.isBreakOverlayVisible = false

        model.tick(now: start.addingTimeInterval(61))

        XCTAssertEqual(coordinator.showBreakOverlayCalls, 2)
        XCTAssertTrue(coordinator.isBreakOverlayVisible)
    }

    func testHiddenReminderPanelIsShownAgainWhileReminderStateIsActive() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 120,
            breakDuration: 20,
            reminderLeadTime: 60,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(60))
        coordinator.isBreakReminderVisible = false

        model.tick(now: start.addingTimeInterval(61))

        XCTAssertEqual(coordinator.showBreakReminderCalls, 2)
        XCTAssertTrue(coordinator.isBreakReminderVisible)
    }

    func testDelayedTickStartsBreakUsingAbsoluteTime() throws {
        let coordinator = MockWindowCoordinator()
        let model = try makeModel(
            workInterval: 60,
            breakDuration: 20,
            reminderLeadTime: 0,
            windowCoordinator: coordinator
        )
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        model.handleAppDidFinishLaunching(now: start)
        model.tick(now: start.addingTimeInterval(300))

        XCTAssertEqual(model.appState.timerPhase, .breakTime)
        XCTAssertNotNil(model.appState.activeBreak)
        XCTAssertEqual(coordinator.showBreakOverlayCalls, 1)
    }

    private func makeModel(
        workInterval: TimeInterval,
        breakDuration: TimeInterval,
        reminderLeadTime: TimeInterval,
        windowCoordinator: MockWindowCoordinator
    ) throws -> AppModel {
        var settings = completedSettings()
        settings.breakSettings.workInterval = workInterval
        settings.breakSettings.microBreakDuration = breakDuration
        settings.breakSettings.reminderLeadTime = reminderLeadTime
        settings.smartPauseSettings.pauseDuringFullscreenFocus = false
        let store = try makeStore(with: settings)

        return AppModel(
            settingsStore: store,
            activityMonitor: MockActivityMonitor(idleSeconds: 0),
            windowCoordinator: windowCoordinator,
            launchConfiguration: AppLaunchConfiguration(forceOnboarding: false),
            startsTimer: false,
            observesSystemEvents: false
        )
    }

    private func completedSettings() -> AppSettings {
        var settings = AppSettings.default
        settings.onboardingState = OnboardingState(
            hasCompletedStarterSetup: true,
            completedAt: Date(timeIntervalSinceReferenceDate: 1234),
            lastCompletedVersion: AppSettings.currentSchemaVersion
        )
        return settings
    }

    private func makeStore(with settings: AppSettings) throws -> SettingsStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SettingsStore(fileURL: directory.appendingPathComponent("settings.json"))
        try store.save(settings)
        return store
    }
}
