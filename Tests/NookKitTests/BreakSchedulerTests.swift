import Foundation
import NookKit
import XCTest

final class BreakSchedulerTests: XCTestCase {
    private final class MockPauseConditionProvider: PauseConditionProvider, @unchecked Sendable {
        let name: String
        var isPauseActive: Bool

        init(name: String = "Full-Screen Focus", isPauseActive: Bool = false) {
            self.name = name
            self.isPauseActive = isPauseActive
        }

        func isPaused(at date: Date) -> Bool {
            _ = date
            return isPauseActive
        }
    }

    func testSchedulerStartsMicroBreakWhenIntervalElapses() {
        let scheduler = BreakScheduler(settings: .default)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(20 * 60), idleSeconds: 0)

        XCTAssertTrue(snapshot.breakJustStarted)
        XCTAssertEqual(snapshot.state.activeBreak?.kind, .micro)
    }

    func testLongBreakArrivesAfterConfiguredCadence() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.breakSettings.microBreakDuration = 10
        settings.breakSettings.longBreakDuration = 120
        settings.breakSettings.longBreakCadence = 2
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(60), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(70), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(130), idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(140), idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(200), idleSeconds: 0)

        XCTAssertEqual(snapshot.state.activeBreak?.kind, .long)
    }

    func testPostponePushesTheNextBreakOut() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let postponed = scheduler.postpone(minutes: 5, now: start.addingTimeInterval(30))

        XCTAssertEqual(postponed.state.nextBreakDate, start.addingTimeInterval(330))
    }

    func testHardcoreModePreventsSkippingActiveBreaks() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.breakSettings.skipPolicy = .hardcore
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        _ = scheduler.advance(to: start.addingTimeInterval(60), idleSeconds: 0)
        let skipped = scheduler.skipCurrentBreak(at: start.addingTimeInterval(61))

        XCTAssertNotNil(skipped.state.activeBreak)
    }

    func testSchedulerResetsAfterUserIsIdle() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.breakSettings.reminderLeadTime = 0
        settings.scheduleSettings.idleResetThreshold = 120
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let snapshot = scheduler.advance(to: start.addingTimeInterval(30), idleSeconds: 180)

        XCTAssertEqual(snapshot.state.nextBreakDate, start.addingTimeInterval(90))
        XCTAssertNil(snapshot.state.reminder)
        XCTAssertNil(snapshot.state.activeBreak)
    }

    func testOfficeHoursBlockBreaksOutsideSchedule() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 60
        settings.scheduleSettings.officeHours = [
            OfficeHoursRule(weekday: 2, startMinutes: 9 * 60, endMinutes: 10 * 60),
        ]

        let calendar = Calendar(identifier: .gregorian)
        let scheduler = BreakScheduler(settings: settings, calendar: calendar)
        let outside = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 11, minute: 0))!
        let snapshot = scheduler.advance(to: outside, idleSeconds: 0)

        XCTAssertNil(snapshot.state.nextBreakDate)
        XCTAssertEqual(snapshot.state.statusText, "Outside office hours")
    }

    @MainActor
    func testSmartPauseSuppressesReminderAndBreakWhileProviderIsActive() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        settings.breakSettings.reminderLeadTime = 60
        let provider = MockPauseConditionProvider(isPauseActive: true)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        let pausedReminder = scheduler.advance(to: start.addingTimeInterval(80), idleSeconds: 0)
        let pausedBreak = scheduler.advance(to: start.addingTimeInterval(140), idleSeconds: 0)

        XCTAssertTrue(pausedReminder.state.isPaused)
        XCTAssertEqual(pausedReminder.state.pauseReason, "Full-Screen Focus")
        XCTAssertNil(pausedReminder.state.reminder)
        XCTAssertFalse(pausedReminder.reminderJustActivated)
        XCTAssertNil(pausedBreak.state.activeBreak)
        XCTAssertFalse(pausedBreak.breakJustStarted)
    }

    @MainActor
    func testManualPauseResumePreservesRemainingTime() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        let scheduler = BreakScheduler(settings: settings)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        // Pause 40 seconds into the 120-second interval (80s remaining)
        _ = scheduler.pause(reason: "Paused manually", now: start.addingTimeInterval(40))
        // Resume 30 seconds later
        let resumed = scheduler.resume(now: start.addingTimeInterval(70))

        // Should still have 80s remaining from resume time → break at start+150
        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(150))
        XCTAssertFalse(resumed.state.isPaused)
    }

    func testSmartPauseResumeRestoresRemainingTimeWithoutImmediateBreak() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        settings.breakSettings.reminderLeadTime = 30
        let provider = MockPauseConditionProvider(isPauseActive: false)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        provider.isPauseActive = true
        _ = scheduler.advance(to: start.addingTimeInterval(40), idleSeconds: 0)

        provider.isPauseActive = false
        let resumed = scheduler.advance(to: start.addingTimeInterval(80), idleSeconds: 0)
        let activeTooSoon = scheduler.advance(to: start.addingTimeInterval(159), idleSeconds: 0)
        let breakStarts = scheduler.advance(to: start.addingTimeInterval(160), idleSeconds: 0)

        XCTAssertFalse(resumed.state.isPaused)
        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(160))
        XCTAssertNil(activeTooSoon.state.activeBreak)
        XCTAssertTrue(breakStarts.breakJustStarted)
    }

    @MainActor
    func testSmartPauseOverdueResumeGetsTwoMinuteGracePeriod() {
        var settings = AppSettings.default
        settings.breakSettings.workInterval = 120
        settings.breakSettings.reminderLeadTime = 60
        let provider = MockPauseConditionProvider(isPauseActive: false)
        let scheduler = BreakScheduler(settings: settings, pauseProviders: [provider])
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = scheduler.advance(to: start, idleSeconds: 0)
        provider.isPauseActive = true
        _ = scheduler.advance(to: start.addingTimeInterval(90), idleSeconds: 0)

        provider.isPauseActive = false
        let resumed = scheduler.advance(to: start.addingTimeInterval(200), idleSeconds: 0)
        let stillWaiting = scheduler.advance(to: start.addingTimeInterval(319), idleSeconds: 0)
        let breakStarts = scheduler.advance(to: start.addingTimeInterval(320), idleSeconds: 0)

        XCTAssertEqual(resumed.state.nextBreakDate, start.addingTimeInterval(320))
        XCTAssertNil(resumed.state.reminder)
        XCTAssertNil(stillWaiting.state.activeBreak)
        XCTAssertFalse(stillWaiting.reminderJustActivated)
        XCTAssertTrue(breakStarts.breakJustStarted)
    }
}
