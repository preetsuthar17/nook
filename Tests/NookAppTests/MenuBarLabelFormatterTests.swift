import Foundation
@testable import NookKit
@testable import NookApp
import XCTest

final class MenuBarLabelFormatterTests: XCTestCase {
    func testUsesBreakCountdownDuringActiveBreak() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let activeBreak = BreakSession(
            kind: .micro,
            startedAt: now,
            scheduledEnd: now.addingTimeInterval(20),
            message: "Rest your eyes",
            backgroundStyle: .dawn,
            skipAvailableAfter: now
        )
        let state = AppState(
            now: now,
            nextBreakDate: nil,
            activeBreak: activeBreak,
            reminder: nil,
            isPaused: false,
            pauseReason: nil,
            statusText: "Short Break in progress (00:20 left)"
        )

        let content = MenuBarLabelFormatter.content(launchPhase: .ready, state: state)

        XCTAssertEqual(content.symbolName, "pause.circle.fill")
        XCTAssertEqual(content.countdownText, "00:20")
    }

    func testUsesNextBreakCountdownWhenScheduleIsActive() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = AppState(
            now: now,
            nextBreakDate: now.addingTimeInterval(5 * 60),
            activeBreak: nil,
            reminder: nil,
            isPaused: false,
            pauseReason: nil,
            statusText: "Next break in 05:00"
        )

        let content = MenuBarLabelFormatter.content(launchPhase: .ready, state: state)

        XCTAssertEqual(content.symbolName, "hourglass")
        XCTAssertEqual(content.countdownText, "05:00")
    }

    func testUsesReminderSymbolWhileReminderIsVisible() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = AppState(
            now: now,
            nextBreakDate: now.addingTimeInterval(45),
            activeBreak: nil,
            reminder: ReminderState(
                dueDate: now,
                scheduledBreakDate: now.addingTimeInterval(45)
            ),
            isPaused: false,
            pauseReason: nil,
            statusText: "Break coming up in 00:45"
        )

        let content = MenuBarLabelFormatter.content(launchPhase: .ready, state: state)

        XCTAssertEqual(content.symbolName, "bell.badge.fill")
        XCTAssertEqual(content.countdownText, "00:45")
    }

    func testUsesPausedIconWithoutFrozenTimer() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = AppState(
            now: now,
            nextBreakDate: now.addingTimeInterval(5 * 60),
            activeBreak: nil,
            reminder: nil,
            isPaused: true,
            pauseReason: "Full-Screen Focus",
            statusText: "Paused by Full-Screen Focus"
        )

        let content = MenuBarLabelFormatter.content(launchPhase: .ready, state: state)

        XCTAssertEqual(content.symbolName, "pause.fill")
        XCTAssertNil(content.countdownText)
    }
}
