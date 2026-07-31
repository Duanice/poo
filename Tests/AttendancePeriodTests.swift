import XCTest
@testable import Daka

final class AttendancePeriodTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    func testDateBeforeTwentyFifthBelongsToPeriodEndingThisMonth() {
        let period = AttendancePeriodCalculator.period(
            containing: date(2026, 8, 24, 18),
            calendar: calendar
        )
        XCTAssertEqual(components(period.start), [2026, 7, 25])
        XCTAssertEqual(components(period.endExclusive), [2026, 8, 25])
    }

    func testTwentyFifthStartsNextNamedPeriod() {
        let period = AttendancePeriodCalculator.period(
            containing: date(2026, 8, 25, 0),
            calendar: calendar
        )
        XCTAssertEqual(components(period.start), [2026, 8, 25])
        XCTAssertEqual(components(period.endExclusive), [2026, 9, 25])
    }

    func testPeriodCrossesYearBoundary() {
        let period = AttendancePeriodCalculator.period(
            containing: date(2027, 1, 4),
            calendar: calendar
        )
        XCTAssertEqual(components(period.start), [2026, 12, 25])
        XCTAssertEqual(components(period.endExclusive), [2027, 1, 25])
    }

    func testLeapYearPeriodIncludesFebruaryTwentyNinth() {
        let period = AttendancePeriodCalculator.period(
            containing: date(2028, 3, 10),
            calendar: calendar
        )
        XCTAssertTrue(period.contains(date(2028, 2, 29)))
        XCTAssertEqual(period.allDays(calendar: calendar).count, 29)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }

    private func components(_ date: Date) -> [Int] {
        let value = calendar.dateComponents([.year, .month, .day], from: date)
        return [value.year!, value.month!, value.day!]
    }
}
