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
