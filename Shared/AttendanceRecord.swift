import Foundation
import SwiftData

@Model
final class AttendanceRecord {
    @Attribute(.unique) var id: UUID
    var workDate: Date
    var checkIn: Date?
    var checkOut: Date?
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var isSlackingFlag: Bool?

    init(
        id: UUID = UUID(),
        workDate: Date,
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        note: String = "",
        isSlacking: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workDate = Calendar.autoupdatingCurrent.startOfDay(for: workDate)
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.note = note
        self.isSlackingFlag = isSlacking
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isSlacking: Bool {
        isSlackingFlag == true
    }

    var durationMinutes: Int {
        guard !isSlacking else { return 0 }
        return AttendanceCalculator.durationMinutes(checkIn: checkIn, checkOut: checkOut)
    }

    var isComplete: Bool {
        !isSlacking && checkIn != nil && checkOut != nil && durationMinutes > 0
    }
}

enum AttendanceSummaryBuilder {
    static func make(
        period: AttendancePeriod,
        records: [AttendanceRecord],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [DailyAttendanceSummary] {
        period.allDays(calendar: calendar).map { day in
            let record = records.first {
                calendar.isDate($0.workDate, inSameDayAs: day)
            }
            return DailyAttendanceSummary(
                date: day,
                durationMinutes: record?.durationMinutes ?? 0,
                isComplete: record?.isComplete ?? false,
                isPartial: record != nil
                    && record?.isSlacking != true
                    && record?.isComplete != true
                    && (record?.checkIn != nil || record?.checkOut != nil),
                isSlacking: record?.isSlacking ?? false
            )
        }
    }
}
