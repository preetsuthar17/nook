import Core
import XCTest

final class TimeIntervalFormattingTests: XCTestCase {
    func testCountdownStringUsesSharedMmSsFormatting() {
        XCTAssertEqual(TimeInterval(60).countdownString, "01:00")
        XCTAssertEqual(TimeInterval(59.6).countdownString, "01:00")
        XCTAssertEqual(TimeInterval(0.4).countdownString, "00:01")
        XCTAssertEqual(TimeInterval(0).countdownString, "00:00")
    }
}
