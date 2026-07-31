import Foundation

@main
struct DomainSmokeTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour
                )
            )!
        }

        func components(_ value: Date) -> [Int] {
            let result = calendar.dateComponents([.year, .month, .day], from: value)
            return [result.year!, result.month!, result.day!]
        }

        let beforeBoundary = AttendancePeriodCalculator.period(
            containing: date(2026, 8, 24, 23),
            calendar: calendar
        )
        precondition(components(beforeBoundary.start) == [2026, 7, 25])
        precondition(components(beforeBoundary.endExclusive) == [2026, 8, 25])

        let onBoundary = AttendancePeriodCalculator.period(
            containing: date(2026, 8, 25, 0),
            calendar: calendar
        )
        precondition(components(onBoundary.start) == [2026, 8, 25])
        precondition(components(onBoundary.endExclusive) == [2026, 9, 25])

        let leapPeriod = AttendancePeriodCalculator.period(
            containing: date(2028, 3, 10),
            calendar: calendar
        )
        precondition(leapPeriod.contains(date(2028, 2, 29)))
        precondition(leapPeriod.allDays(calendar: calendar).count == 29)

        let checkIn = date(2026, 8, 4, 10)
        let checkOut = checkIn.addingTimeInterval(12 * 60 * 60 + 35 * 60)
        precondition(
            AttendanceCalculator.durationMinutes(
                checkIn: checkIn,
                checkOut: checkOut
            ) == 755
        )
        precondition(
            AttendanceCalculator.durationMinutes(
                checkIn: checkIn,
                checkOut: nil
            ) == 0
        )
        precondition(AttendanceCalculator.formatDuration(755) == "12 小时 35 分")

        let catchUpPeriod = AttendancePeriod(
            start: calendar.startOfDay(for: date(2026, 8, 20)),
            endExclusive: calendar.startOfDay(for: date(2026, 8, 25))
        )
        let summaries = catchUpPeriod.allDays(calendar: calendar).map {
            DailyAttendanceSummary(
                date: $0,
                durationMinutes: 0,
                isComplete: false,
                isPartial: false,
                isSlacking: false
            )
        }
        let catchUpPlan = CatchUpPlanCalculator.plan(
            period: catchUpPeriod,
            summaries: summaries,
            targetMinutes: 40 * 60,
            now: date(2026, 8, 20),
            calendar: calendar
        )
        precondition(catchUpPlan.eligibleDays == 5)
        precondition(catchUpPlan.requiredMinutesPerDay == 8 * 60)

        print("Domain smoke tests passed")
    }
}
