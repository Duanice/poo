import XCTest
@testable import Daka

final class AttendanceCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

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

    func testCatchUpPlanUsesOnlyRemainingEligibleDays() {
        let period = testPeriod()
        var summaries = period.allDays(calendar: calendar).enumerated().map { index, date in
            DailyAttendanceSummary(
                date: date,
                durationMinutes: index < 15 ? 8 * 60 : 0,
                isComplete: index < 15,
                isPartial: false,
                isSlacking: false,
                isOffsiteStudy: false
            )
        }
        let now = date(2026, 7, 16, 10)

        var plan = CatchUpPlanCalculator.plan(
            period: period,
            summaries: summaries,
            targetMinutes: 160 * 60,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(plan.completedMinutes, 120 * 60)
        XCTAssertEqual(plan.eligibleDays, 5)
        XCTAssertEqual(plan.requiredMinutesPerDay, 8 * 60)

        summaries[15] = DailyAttendanceSummary(
            date: summaries[15].date,
            durationMinutes: 0,
            isComplete: false,
            isPartial: false,
            isSlacking: true,
            isOffsiteStudy: false
        )
        plan = CatchUpPlanCalculator.plan(
            period: period,
            summaries: summaries,
            targetMinutes: 160 * 60,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(plan.eligibleDays, 4)
        XCTAssertEqual(plan.requiredMinutesPerDay, 10 * 60)

        summaries[16] = DailyAttendanceSummary(
            date: summaries[16].date,
            durationMinutes: 0,
            isComplete: false,
            isPartial: false,
            isSlacking: false,
            isOffsiteStudy: true
        )
        plan = CatchUpPlanCalculator.plan(
            period: period,
            summaries: summaries,
            targetMinutes: 160 * 60,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(plan.eligibleDays, 3)
        XCTAssertEqual(plan.requiredMinutesPerDay, 800)
    }

    func testCatchUpPlanReportsImpossibleWhenAllRemainingDaysAreSlacking() {
        let period = testPeriod()
        let now = date(2026, 7, 16, 10)
        let summaries = period.allDays(calendar: calendar).enumerated().map { index, date in
            DailyAttendanceSummary(
                date: date,
                durationMinutes: index < 15 ? 8 * 60 : 0,
                isComplete: index < 15,
                isPartial: false,
                isSlacking: index >= 15,
                isOffsiteStudy: false
            )
        }

        let plan = CatchUpPlanCalculator.plan(
            period: period,
            summaries: summaries,
            targetMinutes: 160 * 60,
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(plan.isImpossible)
        XCTAssertEqual(plan.loadLevel, .impossible)
        XCTAssertEqual(plan.requiredMinutesPerDay, 0)
    }

    func testCatchUpPlanRoundsRequiredMinutesUp() {
        let start = date(2026, 7, 1, 0)
        let period = AttendancePeriod(
            start: start,
            endExclusive: date(2026, 7, 3, 0)
        )
        let summaries = period.allDays(calendar: calendar).map {
            DailyAttendanceSummary(
                date: $0,
                durationMinutes: 0,
                isComplete: false,
                isPartial: false,
                isSlacking: false,
                isOffsiteStudy: false
            )
        }

        let plan = CatchUpPlanCalculator.plan(
            period: period,
            summaries: summaries,
            targetMinutes: 121,
            now: start,
            calendar: calendar
        )

        XCTAssertEqual(plan.eligibleDays, 2)
        XCTAssertEqual(plan.requiredMinutesPerDay, 61)
    }

    private func testPeriod() -> AttendancePeriod {
        AttendancePeriod(
            start: date(2026, 7, 1, 0),
            endExclusive: date(2026, 7, 21, 0)
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int
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
}
