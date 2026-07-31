import Foundation

enum AttendanceCalculator {
    static func durationMinutes(checkIn: Date?, checkOut: Date?) -> Int {
        guard let checkIn, let checkOut, checkOut > checkIn else {
            return 0
        }
        return max(0, Int(checkOut.timeIntervalSince(checkIn) / 60))
    }

    static func date(
        on workDate: Date,
        minuteOfDay: Int,
        dayOffset: Int = 0,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let normalizedMinute = min(max(minuteOfDay, 0), 23 * 60 + 59)
        let base = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: workDate))!
        return calendar.date(
            bySettingHour: normalizedMinute / 60,
            minute: normalizedMinute % 60,
            second: 0,
            of: base
        )!
    }

    static func minuteOfDay(
        from date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func formatDuration(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60
        if hours == 0 {
            return "\(remainder) 分钟"
        }
        if remainder == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(remainder) 分"
    }

    static func compactDuration(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

enum CatchUpLoadLevel: String, Sendable {
    case completed
    case normal
    case warning
    case critical
    case impossible
}

struct CatchUpPlan: Sendable, Equatable {
    let completedMinutes: Int
    let remainingMinutes: Int
    let eligibleDays: Int
    let requiredMinutesPerDay: Int
    let loadLevel: CatchUpLoadLevel

    var isCompleted: Bool {
        remainingMinutes == 0
    }

    var isImpossible: Bool {
        remainingMinutes > 0 && eligibleDays == 0
    }
}

struct DailyAttendanceSummary: Sendable, Identifiable, Equatable {
    let date: Date
    let durationMinutes: Int
    let isComplete: Bool
    let isPartial: Bool
    let isSlacking: Bool

    var id: Date { date }
}

enum CatchUpPlanCalculator {
    static func plan(
        period: AttendancePeriod,
        summaries: [DailyAttendanceSummary],
        targetMinutes: Int,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CatchUpPlan {
        let today = calendar.startOfDay(for: now)
        let summariesInPeriod = summaries.filter { period.contains($0.date) }
        let completedMinutes = summariesInPeriod
            .filter { $0.date <= today }
            .reduce(0) { $0 + $1.durationMinutes }
        let remainingMinutes = max(0, targetMinutes - completedMinutes)

        let eligibleDays = period.allDays(calendar: calendar).filter { day in
            guard day >= today else { return false }
            let summary = summariesInPeriod.first {
                calendar.isDate($0.date, inSameDayAs: day)
            }
            return summary?.isSlacking != true && summary?.isComplete != true
        }.count

        let requiredMinutes: Int
        if remainingMinutes == 0 || eligibleDays == 0 {
            requiredMinutes = 0
        } else {
            requiredMinutes = (remainingMinutes + eligibleDays - 1) / eligibleDays
        }

        let level: CatchUpLoadLevel
        if remainingMinutes == 0 {
            level = .completed
        } else if eligibleDays == 0 {
            level = .impossible
        } else if requiredMinutes > 16 * 60 {
            level = .critical
        } else if requiredMinutes > 12 * 60 {
            level = .warning
        } else {
            level = .normal
        }

        return CatchUpPlan(
            completedMinutes: completedMinutes,
            remainingMinutes: remainingMinutes,
            eligibleDays: eligibleDays,
            requiredMinutesPerDay: requiredMinutes,
            loadLevel: level
        )
    }
}
