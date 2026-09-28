import SwiftData
import XCTest
@testable import Daka

@MainActor
final class AttendanceMutationServiceTests: XCTestCase {
    func testSavingSameDayUpdatesInsteadOfDuplicating() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = AttendanceMutationService(context: context)
        let workDate = Date.now
        let firstStart = AttendanceCalculator.date(on: workDate, minuteOfDay: 600)
        let firstEnd = AttendanceCalculator.date(on: workDate, minuteOfDay: 1_320)

        try service.save(
            workDate: workDate,
            checkIn: firstStart,
            checkOut: firstEnd,
            note: "第一次"
        )
        try service.save(
            workDate: workDate,
            checkIn: firstStart,
            checkOut: firstEnd.addingTimeInterval(30 * 60),
            note: "已修改"
        )

        let records = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.durationMinutes, 750)
        XCTAssertEqual(records.first?.note, "已修改")
    }

    func testCheckOutRequiresCheckIn() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = AttendanceMutationService(context: context)

        XCTAssertThrowsError(try service.checkOutNow())
    }

    func testSettingAndCancellingEmptySlackingDay() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = AttendanceMutationService(context: context)
        let workDate = Date.now

        try service.setSlacking(on: workDate, enabled: true)

        var records = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(records[0].isSlacking)
        XCTAssertEqual(records[0].durationMinutes, 0)

        try service.setSlacking(on: workDate, enabled: false)

        records = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertTrue(records.isEmpty)
    }

    func testSlackingExistingRecordRequiresExplicitClear() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = AttendanceMutationService(context: context)
        let workDate = Date.now
        let checkIn = AttendanceCalculator.date(on: workDate, minuteOfDay: 600)
        let checkOut = AttendanceCalculator.date(on: workDate, minuteOfDay: 1_320)

        try service.save(
            workDate: workDate,
            checkIn: checkIn,
            checkOut: checkOut,
            note: ""
        )

        XCTAssertThrowsError(
            try service.setSlacking(on: workDate, enabled: true)
        ) { error in
            guard case AttendanceMutationError.existingRecordRequiresConfirmation = error else {
                return XCTFail("应要求用户确认清空已有记录")
            }
        }

        try service.setSlacking(
            on: workDate,
            enabled: true,
            clearExistingRecord: true
        )

        let record = try XCTUnwrap(service.record(on: workDate))
        XCTAssertTrue(record.isSlacking)
        XCTAssertNil(record.checkIn)
        XCTAssertNil(record.checkOut)
        XCTAssertEqual(record.durationMinutes, 0)
    }

    func testOffsiteStudyIsExclusiveAndDoesNotCountAttendance() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = AttendanceMutationService(context: context)
        let workDate = Date.now

        try service.setSlacking(on: workDate, enabled: true)
        try service.setOffsiteStudy(on: workDate, enabled: true)

        var record = try XCTUnwrap(service.record(on: workDate))
        XCTAssertTrue(record.isOffsiteStudy)
        XCTAssertFalse(record.isSlacking)
        XCTAssertEqual(record.durationMinutes, 0)

        try service.setOffsiteStudy(on: workDate, enabled: false)
        XCTAssertNil(try service.record(on: workDate))

        let checkIn = AttendanceCalculator.date(on: workDate, minuteOfDay: 600)
        let checkOut = AttendanceCalculator.date(on: workDate, minuteOfDay: 1_320)
        try service.save(
            workDate: workDate,
            checkIn: checkIn,
            checkOut: checkOut,
            note: ""
        )
        XCTAssertThrowsError(
            try service.setOffsiteStudy(on: workDate, enabled: true)
        )
        try service.setOffsiteStudy(
            on: workDate,
            enabled: true,
            clearExistingRecord: true
        )
        record = try XCTUnwrap(service.record(on: workDate))
        XCTAssertTrue(record.isOffsiteStudy)
        XCTAssertNil(record.checkIn)
        XCTAssertNil(record.checkOut)
    }

    func testVersionOneBackupWithoutSlackingFieldStillDecodes() throws {
        let data = Data(
            """
            {
              "formatVersion": 1,
              "exportedAt": "2026-07-31T05:00:00Z",
              "appName": "中关村实验室打卡 for 段冰洁",
              "records": [
                {
                  "id": "88B54E42-76B8-4A06-92CC-784B57410E86",
                  "workDate": "2026-07-30T16:00:00Z",
                  "checkIn": "2026-07-31T02:00:00Z",
                  "checkOut": "2026-07-31T14:00:00Z",
                  "note": "",
                  "createdAt": "2026-07-31T02:00:00Z",
                  "updatedAt": "2026-07-31T14:00:00Z"
                }
              ]
            }
            """.utf8
        )

        let backup = try BackupService.decode(data)

        XCTAssertEqual(backup.formatVersion, 1)
        XCTAssertEqual(backup.records.count, 1)
        XCTAssertNil(backup.records[0].isSlacking)
        XCTAssertNil(backup.records[0].isOffsiteStudy)
    }

    func testVersionFiveBackupPreservesDayStates() throws {
        let record = AttendanceRecord(
            workDate: .now,
            isOffsiteStudy: true
        )

        let data = try BackupService.jsonData(records: [record])
        let backup = try BackupService.decode(data)

        XCTAssertEqual(backup.formatVersion, 5)
        XCTAssertEqual(backup.records.first?.isSlacking, false)
        XCTAssertEqual(backup.records.first?.isOffsiteStudy, true)
    }
}
