import Foundation
import SwiftData

enum AttendanceMutationError: LocalizedError {
    case invalidTimeRange
    case missingCheckIn
    case existingRecordRequiresConfirmation
    case existingRecordRequiresOffsiteStudyConfirmation

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "下班时间必须晚于上班时间；如跨午夜，请启用“跨午夜”。"
        case .missingCheckIn:
            return "请先设置上班时间。"
        case .existingRecordRequiresConfirmation:
            return "该日期已有打卡时间。请确认清空记录后再设为摆烂日。"
        case .existingRecordRequiresOffsiteStudyConfirmation:
            return "该日期已有打卡时间。请确认清空记录后再设为外出自习。"
        }
    }
}

@MainActor
struct AttendanceMutationService {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .autoupdatingCurrent) {
        self.context = context
        self.calendar = calendar
    }

    func record(on date: Date) throws -> AttendanceRecord? {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<AttendanceRecord>(
            predicate: #Predicate { record in
                record.workDate >= start && record.workDate < end
            }
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func save(
        workDate: Date,
        checkIn: Date?,
        checkOut: Date?,
        note: String
    ) throws -> AttendanceRecord {
        if let checkIn, let checkOut, checkOut <= checkIn {
            throw AttendanceMutationError.invalidTimeRange
        }
        let existing = try record(on: workDate)
        let item = existing ?? AttendanceRecord(workDate: workDate)
        if existing == nil {
            context.insert(item)
        }
        item.workDate = calendar.startOfDay(for: workDate)
        item.checkIn = checkIn
        item.checkOut = checkOut
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.isSlackingFlag = false
        item.isOffsiteStudyFlag = false
        item.updatedAt = .now
        try context.save()
        return item
    }

    func checkInNow(on date: Date = .now) throws {
        let existing = try record(on: date)
        let item = existing ?? AttendanceRecord(workDate: date)
        if existing == nil {
            context.insert(item)
        }
        item.isSlackingFlag = false
        item.isOffsiteStudyFlag = false
        item.checkIn = date
        if let checkOut = item.checkOut, checkOut <= date {
            item.checkOut = nil
        }
        item.updatedAt = .now
        try context.save()
    }

    func setSlacking(
        on date: Date,
        enabled: Bool,
        clearExistingRecord: Bool = false
    ) throws {
        let existing = try record(on: date)

        if enabled {
            if let existing,
               existing.hasAnyEffectiveTime,
               !clearExistingRecord {
                throw AttendanceMutationError.existingRecordRequiresConfirmation
            }

            let item = existing ?? AttendanceRecord(workDate: date)
            if existing == nil {
                context.insert(item)
            }
            if clearExistingRecord {
                clearAttendanceData(on: item)
            }
            item.isSlackingFlag = true
            item.isOffsiteStudyFlag = false
            item.updatedAt = .now
        } else if let existing {
            existing.isSlackingFlag = false
            existing.updatedAt = .now
            if existing.checkIn == nil,
               existing.checkOut == nil,
               !existing.hasActualData,
               !existing.isOffsiteStudy,
               existing.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.delete(existing)
            }
        }

        try context.save()
    }

    func setOffsiteStudy(
        on date: Date,
        enabled: Bool,
        clearExistingRecord: Bool = false
    ) throws {
        let existing = try record(on: date)

        if enabled {
            if let existing,
               existing.hasAnyEffectiveTime,
               !clearExistingRecord {
                throw AttendanceMutationError.existingRecordRequiresOffsiteStudyConfirmation
            }

            let item = existing ?? AttendanceRecord(workDate: date)
            if existing == nil {
                context.insert(item)
            }
            if clearExistingRecord {
                clearAttendanceData(on: item)
            }
            item.isOffsiteStudyFlag = true
            item.isSlackingFlag = false
            item.updatedAt = .now
        } else if let existing {
            existing.isOffsiteStudyFlag = false
            existing.updatedAt = .now
            if existing.checkIn == nil,
               existing.checkOut == nil,
               !existing.hasActualData,
               !existing.isSlacking,
               existing.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.delete(existing)
            }
        }

        try context.save()
    }

    func clearActualData(on date: Date) throws {
        guard let item = try record(on: date) else { return }
        item.actualCheckIn = nil
        item.actualCheckOut = nil
        item.actualDurationMinutes = nil
        item.actualImportedAt = nil
        item.actualImportBatchID = nil
        item.updatedAt = .now
        if item.checkIn == nil,
           item.checkOut == nil,
           !item.isSlacking,
           !item.isOffsiteStudy,
           item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.delete(item)
        }
        try context.save()
    }

    func checkOutNow(on date: Date = .now) throws {
        guard let item = try record(on: date), let checkIn = item.checkIn else {
            throw AttendanceMutationError.missingCheckIn
        }
        guard date > checkIn else {
            throw AttendanceMutationError.invalidTimeRange
        }
        item.checkOut = date
        item.updatedAt = .now
        try context.save()
    }

    func delete(on date: Date) throws {
        if let item = try record(on: date) {
            context.delete(item)
            try context.save()
        }
    }

    private func clearAttendanceData(on item: AttendanceRecord) {
        item.checkIn = nil
        item.checkOut = nil
        item.actualCheckIn = nil
        item.actualCheckOut = nil
        item.actualDurationMinutes = nil
        item.actualImportedAt = nil
        item.actualImportBatchID = nil
    }
}
