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
}
