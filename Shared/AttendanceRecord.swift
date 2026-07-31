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

    init(
        id: UUID = UUID(),
        workDate: Date,
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workDate = Calendar.autoupdatingCurrent.startOfDay(for: workDate)
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var durationMinutes: Int {
        AttendanceCalculator.durationMinutes(checkIn: checkIn, checkOut: checkOut)
    }

    var isComplete: Bool {
        checkIn != nil && checkOut != nil && durationMinutes > 0
    }
}
