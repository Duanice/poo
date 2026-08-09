import SwiftData
import XCTest
@testable import Daka

@MainActor
final class BowelMovementTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    func testMultipleMovementsCanBeEditedAndDeletedIndependently() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = BowelMovementMutationService(context: context)
        let now = makeDate(2026, 8, 9, 20, 0)
        let first = try service.save(
            occurredAt: makeDate(2026, 8, 7, 9, 10),
            note: "  正常  ",
            now: now
        )
        let second = try service.save(
            occurredAt: makeDate(2026, 8, 7, 18, 30),
            note: "第二次",
            now: now
        )

        var records = try context.fetch(FetchDescriptor<BowelMovementRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(first.note, "正常")

        _ = try service.save(
            id: first.id,
            occurredAt: makeDate(2026, 8, 7, 9, 20),
            note: "已修改",
            now: now
        )
        try service.delete(id: second.id)

        records = try context.fetch(FetchDescriptor<BowelMovementRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, first.id)
        XCTAssertEqual(records[0].note, "已修改")
        XCTAssertEqual(
            calendar.component(.minute, from: records[0].occurredAt),
            20
        )
    }

    func testDayStatusTurnsPastEmptyDayIntoNoMovement() {
        let now = makeDate(2026, 8, 9, 12, 0)
        let movements = [
            BowelMovementRecord(occurredAt: makeDate(2026, 8, 9, 8, 0)),
            BowelMovementRecord(occurredAt: makeDate(2026, 8, 9, 10, 0))
        ]

        XCTAssertEqual(
            BowelDayStatusResolver.status(
                on: makeDate(2026, 8, 8, 12, 0),
                records: [],
                now: now,
                calendar: calendar
            ),
            .noMovement
        )
        XCTAssertEqual(
            BowelDayStatusResolver.status(
                on: now,
                records: [],
                now: now,
                calendar: calendar
            ),
            .pending
        )
        XCTAssertEqual(
            BowelDayStatusResolver.status(
                on: makeDate(2026, 8, 10, 12, 0),
                records: [],
                now: now,
                calendar: calendar
            ),
            .future
        )
        XCTAssertEqual(
            BowelDayStatusResolver.status(
                on: now,
                records: movements,
                now: now,
                calendar: calendar
            ),
            .recorded(2)
        )
    }

    func testFutureMovementIsRejected() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let service = BowelMovementMutationService(
            context: ModelContext(container)
        )
        let now = makeDate(2026, 8, 9, 12, 0)

        XCTAssertThrowsError(
            try service.save(
                occurredAt: makeDate(2026, 8, 10, 12, 0),
                note: "",
                now: now
            )
        ) { error in
            guard case BowelMovementMutationError.futureDate = error else {
                return XCTFail("未来时间必须被拒绝")
            }
        }
    }

    func testVersionFourBackupPreservesBowelMovements() throws {
        let first = BowelMovementRecord(
            occurredAt: makeDate(2026, 8, 7, 9, 10),
            note: "第一次"
        )
        let second = BowelMovementRecord(
            occurredAt: makeDate(2026, 8, 7, 18, 30),
            note: "第二次"
        )

        let backup = try BackupService.decode(
            try BackupService.jsonData(
                records: [],
                bowelMovements: [first, second]
            )
        )

        XCTAssertEqual(backup.formatVersion, 4)
        XCTAssertEqual(backup.bowelMovements?.count, 2)
        XCTAssertEqual(backup.bowelMovements?.map(\.note), ["第一次", "第二次"])
    }

    func testVersionThreeBackupWithoutBowelDataStillDecodes() throws {
        let data = Data(
            """
            {
              "formatVersion": 3,
              "exportedAt": "2026-08-09T04:00:00Z",
              "appName": "中关村实验室打卡 for 段冰洁",
              "records": []
            }
            """.utf8
        )

        let backup = try BackupService.decode(data)

        XCTAssertEqual(backup.formatVersion, 3)
        XCTAssertNil(backup.bowelMovements)
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
