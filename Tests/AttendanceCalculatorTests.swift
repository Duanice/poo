import XCTest
@testable import Daka

final class AttendanceCalculatorTests: XCTestCase {
    func testCompleteRecordCalculatesExactMinutes() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let end = start.addingTimeInterval(12 * 60 * 60 + 25 * 60)
        XCTAssertEqual(
            AttendanceCalculator.durationMinutes(checkIn: start, checkOut: end),
            745
        )
    }

    func testMissingTimeIsZero() {
        XCTAssertEqual(
            AttendanceCalculator.durationMinutes(checkIn: .now, checkOut: nil),
            0
        )
        XCTAssertEqual(
            AttendanceCalculator.durationMinutes(checkIn: nil, checkOut: .now),
            0
        )
    }

    func testInvalidRangeIsZero() {
        let now = Date.now
        XCTAssertEqual(
            AttendanceCalculator.durationMinutes(
                checkIn: now,
                checkOut: now.addingTimeInterval(-60)
            ),
            0
        )
    }

    func testHumanReadableFormatting() {
        XCTAssertEqual(AttendanceCalculator.formatDuration(0), "0 分钟")
        XCTAssertEqual(AttendanceCalculator.formatDuration(60), "1 小时")
        XCTAssertEqual(AttendanceCalculator.formatDuration(755), "12 小时 35 分")
    }
}
