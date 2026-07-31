import Foundation

struct AttendancePeriod: Hashable, Sendable {
    let start: Date
    let endExclusive: Date

    var endInclusive: Date {
        endExclusive.addingTimeInterval(-1)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < endExclusive
    }

    func allDays(calendar: Calendar = .autoupdatingCurrent) -> [Date] {
        var result: [Date] = []
        var cursor = start
        while cursor < endExclusive {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return result
    }
}

enum AttendancePeriodCalculator {
    static func period(
        containing date: Date,
        calendar inputCalendar: Calendar = .autoupdatingCurrent
    ) -> AttendancePeriod {
        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone
        let day = calendar.component(.day, from: date)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        )!

        let startMonth: Date
        let endMonth: Date
        if day >= AppConstants.cycleStartDay {
            startMonth = monthStart
            endMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        } else {
            startMonth = calendar.date(byAdding: .month, value: -1, to: monthStart)!
            endMonth = monthStart
        }

        let start = calendar.date(
            bySetting: .day,
            value: AppConstants.cycleStartDay,
            of: startMonth
        )!
        let endInclusive = calendar.date(
            bySetting: .day,
            value: AppConstants.cycleStartDay - 1,
            of: endMonth
        )!
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endInclusive)!
        return AttendancePeriod(
            start: calendar.startOfDay(for: start),
            endExclusive: calendar.startOfDay(for: endExclusive)
        )
    }

    static func shifted(
        _ period: AttendancePeriod,
        byMonths offset: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AttendancePeriod {
        let anchor = calendar.date(byAdding: .month, value: offset, to: period.start)!
        return self.period(containing: anchor, calendar: calendar)
    }
}
