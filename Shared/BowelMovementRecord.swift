import Foundation
import SwiftData

@Model
final class BowelMovementRecord {
    @Attribute(.unique) var id: UUID
    var occurredAt: Date
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum BowelMovementMutationError: LocalizedError {
    case futureDate
    case noteTooLong

    var errorDescription: String? {
        switch self {
        case .futureDate:
            return "不能记录未来时间。"
        case .noteTooLong:
            return "描述最多 500 个字符。"
        }
    }
}

@MainActor
struct BowelMovementMutationService {
    let context: ModelContext

    func save(
        id: UUID? = nil,
        occurredAt: Date,
        note: String,
        now: Date = .now
    ) throws -> BowelMovementRecord {
        guard occurredAt <= now else {
            throw BowelMovementMutationError.futureDate
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 500 else {
            throw BowelMovementMutationError.noteTooLong
        }

        let existing: BowelMovementRecord?
        if let id {
            existing = try record(id: id)
        } else {
            existing = nil
        }
        let item = existing ?? BowelMovementRecord(
            occurredAt: occurredAt,
            createdAt: now,
            updatedAt: now
        )
        if existing == nil {
            context.insert(item)
        }
        item.occurredAt = occurredAt
        item.note = trimmedNote
        item.updatedAt = now
        try context.save()
        return item
    }

    func delete(id: UUID) throws {
        guard let item = try record(id: id) else { return }
        context.delete(item)
        try context.save()
    }

    private func record(id: UUID) throws -> BowelMovementRecord? {
        let descriptor = FetchDescriptor<BowelMovementRecord>(
            predicate: #Predicate { item in
                item.id == id
            }
        )
        return try context.fetch(descriptor).first
    }
}

enum BowelDayStatus: Equatable, Sendable {
    case recorded(Int)
    case noMovement
    case pending
    case future
}

enum BowelDayStatusResolver {
    static func status(
        on date: Date,
        records: [BowelMovementRecord],
        now: Date = .now,
        calendar: Calendar = DakaCalendar.china
    ) -> BowelDayStatus {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let count = records.count {
            calendar.isDate($0.occurredAt, inSameDayAs: day)
        }

        if count > 0 { return .recorded(count) }
        if day < today { return .noMovement }
        if day > today { return .future }
        return .pending
    }
}
