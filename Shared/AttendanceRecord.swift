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
    var isOffsiteStudyFlag: Bool?
    var actualCheckIn: Date?
    var actualCheckOut: Date?
    var actualDurationMinutes: Int?
    var actualImportedAt: Date?
    var actualImportBatchID: UUID?

    init(
        id: UUID = UUID(),
        workDate: Date,
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        note: String = "",
        isSlacking: Bool = false,
        isOffsiteStudy: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        actualCheckIn: Date? = nil,
        actualCheckOut: Date? = nil,
        actualDurationMinutes: Int? = nil,
        actualImportedAt: Date? = nil,
        actualImportBatchID: UUID? = nil
    ) {
        self.id = id
        self.workDate = Calendar.autoupdatingCurrent.startOfDay(for: workDate)
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.note = note
        self.isSlackingFlag = isSlacking
        self.isOffsiteStudyFlag = isOffsiteStudy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.actualCheckIn = actualCheckIn
        self.actualCheckOut = actualCheckOut
        self.actualDurationMinutes = actualDurationMinutes
        self.actualImportedAt = actualImportedAt
        self.actualImportBatchID = actualImportBatchID
    }

    var isSlacking: Bool {
        isSlackingFlag == true
    }

    var isOffsiteStudy: Bool {
        isOffsiteStudyFlag == true
    }

    var isExcludedFromAttendance: Bool {
        isSlacking || isOffsiteStudy
    }

    var hasActualData: Bool {
        actualCheckIn != nil
            && actualCheckOut != nil
            && actualDurationMinutes != nil
    }

    var effectiveCheckIn: Date? {
        hasActualData ? actualCheckIn : checkIn
    }

    var effectiveCheckOut: Date? {
        hasActualData ? actualCheckOut : checkOut
    }

    var hasAnyEffectiveTime: Bool {
        effectiveCheckIn != nil || effectiveCheckOut != nil
    }

    var durationMinutes: Int {
        guard !isExcludedFromAttendance else { return 0 }
        if hasActualData {
            return max(0, actualDurationMinutes ?? 0)
        }
        return AttendanceCalculator.durationMinutes(
            checkIn: checkIn,
            checkOut: checkOut
        )
    }

    var isComplete: Bool {
        !isExcludedFromAttendance
            && effectiveCheckIn != nil
            && effectiveCheckOut != nil
            && durationMinutes > 0
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
                    && record?.isExcludedFromAttendance != true
                    && record?.isComplete != true
                    && record?.hasAnyEffectiveTime == true,
                isSlacking: record?.isSlacking ?? false,
                isOffsiteStudy: record?.isOffsiteStudy ?? false
            )
        }
    }
}
