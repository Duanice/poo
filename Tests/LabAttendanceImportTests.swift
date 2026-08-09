import SwiftData
import XCTest
@testable import Daka

final class LabAttendanceImportParserTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    func testParsesCompleteWeeklyEmailAndMatchesReportedTotal() throws {
        let document = try LabAttendanceImportParser.parse(
            Self.sampleEmail,
            calendar: calendar
        )

        XCTAssertEqual(document.rows.count, 3)
        XCTAssertEqual(document.reportedTotalMinutes, 1_260)
        XCTAssertEqual(document.tableTotalMinutes, 1_260)
        XCTAssertTrue(document.warnings.isEmpty)

        let first = try XCTUnwrap(document.rows.first)
        XCTAssertEqual(first.durationMinutes, 480)
        XCTAssertEqual(timeComponents(first.checkIn), [9, 2])
        XCTAssertEqual(timeComponents(first.checkOut), [17, 1])

        let exactMinutes = document.rows.reduce(0) {
            $0 + AttendanceCalculator.durationMinutes(
                checkIn: $1.checkIn,
                checkOut: $1.checkOut
            )
        }
        XCTAssertEqual(exactMinutes, 1_259)
    }

    func testRejectsMalformedDateRowInsteadOfSilentlySkippingIt() {
        XCTAssertThrowsError(
            try LabAttendanceImportParser.parse(
                """
                日期 上班 下班 时长（小时）
                2026-07-01 09:02 缺失 8.0
                """,
                calendar: calendar
            )
        ) { error in
            guard case LabAttendanceImportError.invalidRows = error else {
                return XCTFail("应报告无法解析的日期行")
            }
        }
    }

    func testRejectsDuplicateDates() {
        XCTAssertThrowsError(
            try LabAttendanceImportParser.parse(
                """
                2026-07-01 10:00 18:00 8.0
                2026-07-01 11:00 19:00 8.0
                """,
                calendar: calendar
            )
        ) { error in
            guard case LabAttendanceImportError.duplicateDates = error else {
                return XCTFail("应拒绝同批次重复日期")
            }
        }
    }

    func testSupportsFullWidthColonAndCrossMidnight() throws {
        let document = try LabAttendanceImportParser.parse(
            "2026-07-01 22：00 02：00 4.0",
            calendar: calendar
        )
        let row = try XCTUnwrap(document.rows.first)
        XCTAssertEqual(
            AttendanceCalculator.durationMinutes(
                checkIn: row.checkIn,
                checkOut: row.checkOut
            ),
            240
        )
    }

    private func timeComponents(_ date: Date) -> [Int] {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return [components.hour!, components.minute!]
    }

    private static let sampleEmail = """
    同学, 您好：

    截至目前，您7月的打卡时长总计21.0小时，详细情况如下表：

    日期 上班 下班 时长（小时）
    2026-07-01 09:02 17:01 8.0
    2026-07-02 10:00 16:31 6.5
    2026-07-03 11:15 17:44 6.5
    """
}

@MainActor
final class LabAttendanceImportServiceTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }

    func testActualImportPreservesManualRecordAndIsIdempotent() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let mutationService = AttendanceMutationService(
            context: context,
            calendar: calendar
        )
        let importService = LabAttendanceImportService(
            context: context,
            calendar: calendar
        )
        let date = makeDate(2026, 7, 1, 0, 0)
        let manualCheckIn = makeDate(2026, 7, 1, 10, 0)
        let manualCheckOut = makeDate(2026, 7, 1, 22, 0)
        try mutationService.save(
            workDate: date,
            checkIn: manualCheckIn,
            checkOut: manualCheckOut,
            note: "手动记录"
        )

        let row = LabAttendanceImportRow(
            workDate: date,
            checkIn: makeDate(2026, 7, 1, 13, 20),
            checkOut: makeDate(2026, 7, 1, 17, 50),
            durationMinutes: 270,
            reportedHours: 4.5,
            lineNumber: 1
        )
        let firstResult = try importService.apply([row])
        let record = try XCTUnwrap(mutationService.record(on: date))

        XCTAssertEqual(firstResult.addedActualData, 1)
        XCTAssertEqual(record.checkIn, manualCheckIn)
        XCTAssertEqual(record.checkOut, manualCheckOut)
        XCTAssertEqual(record.effectiveCheckIn, row.checkIn)
        XCTAssertEqual(record.effectiveCheckOut, row.checkOut)
        XCTAssertEqual(record.durationMinutes, 270)
        XCTAssertEqual(record.note, "手动记录")

        let secondResult = try importService.apply([row])
        XCTAssertEqual(secondResult.unchanged, 1)
        XCTAssertEqual(secondResult.changed, 0)
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<AttendanceRecord>()),
            1
        )
    }

    func testCorrectedWeeklyReportUpdatesExistingActualData() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = LabAttendanceImportService(
            context: context,
            calendar: calendar
        )
        let date = makeDate(2026, 7, 2, 0, 0)
        let original = row(
            date: date,
            checkInMinute: 9 * 60 + 15,
            checkOutMinute: 18 * 60,
            duration: 525
        )
        let corrected = row(
            date: date,
            checkInMinute: 9 * 60 + 15,
            checkOutMinute: 18 * 60 + 20,
            duration: 545
        )

        _ = try service.apply([original])
        let result = try service.apply([corrected])
        let record = try XCTUnwrap(
            try context.fetch(FetchDescriptor<AttendanceRecord>()).first
        )

        XCTAssertEqual(result.updatedActualData, 1)
        XCTAssertEqual(record.actualCheckOut, corrected.checkOut)
        XCTAssertEqual(record.durationMinutes, 545)
        XCTAssertTrue(record.isComplete)
    }

    func testActualOnlyRecordIsCompleteInDailySummary() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = LabAttendanceImportService(
            context: context,
            calendar: calendar
        )
        let date = makeDate(2026, 7, 2, 0, 0)
        _ = try service.apply([
            row(
                date: date,
                checkInMinute: 9 * 60,
                checkOutMinute: 18 * 60,
                duration: 540
            )
        ])

        let record = try XCTUnwrap(
            try context.fetch(FetchDescriptor<AttendanceRecord>()).first
        )
        XCTAssertNil(record.checkIn)
        XCTAssertNil(record.checkOut)
        XCTAssertTrue(record.hasActualData)
        XCTAssertTrue(record.isComplete)

        let period = AttendancePeriodCalculator.period(
            containing: date,
            calendar: calendar
        )
        let summary = try XCTUnwrap(
            AttendanceSummaryBuilder.make(
                period: period,
                records: [record],
                calendar: calendar
            ).first { calendar.isDate($0.date, inSameDayAs: date) }
        )
        XCTAssertTrue(summary.isComplete)
        XCTAssertFalse(summary.isPartial)
        XCTAssertEqual(summary.durationMinutes, 540)
    }

    func testImportFailsSafelyWhenStoredDatesAreDuplicated() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let service = LabAttendanceImportService(
            context: context,
            calendar: calendar
        )
        let date = makeDate(2026, 7, 2, 0, 0)
        context.insert(AttendanceRecord(workDate: date))
        context.insert(AttendanceRecord(workDate: date))
        try context.save()

        XCTAssertThrowsError(
            try service.apply([
                row(
                    date: date,
                    checkInMinute: 9 * 60,
                    checkOutMinute: 18 * 60,
                    duration: 540
                )
            ])
        ) { error in
            guard case LabAttendanceImportApplyError.duplicateStoredDates = error else {
                return XCTFail("重复本地日期应返回可恢复错误，而不是覆盖或崩溃")
            }
        }
    }

    func testExplicitSlackingClearAlsoClearsActualData() throws {
        let container = try AppDataContainer.make(inMemory: true)
        let context = ModelContext(container)
        let importService = LabAttendanceImportService(
            context: context,
            calendar: calendar
        )
        let mutationService = AttendanceMutationService(
            context: context,
            calendar: calendar
        )
        let date = makeDate(2026, 7, 3, 0, 0)
        _ = try importService.apply([
            row(
                date: date,
                checkInMinute: 10 * 60,
                checkOutMinute: 18 * 60,
                duration: 480
            )
        ])

        XCTAssertThrowsError(
            try mutationService.setSlacking(on: date, enabled: true)
        )
        try mutationService.setSlacking(
            on: date,
            enabled: true,
            clearExistingRecord: true
        )

        let record = try XCTUnwrap(mutationService.record(on: date))
        XCTAssertTrue(record.isSlacking)
        XCTAssertFalse(record.hasActualData)
        XCTAssertNil(record.actualCheckIn)
        XCTAssertEqual(record.durationMinutes, 0)
    }

    func testVersionThreeBackupPreservesActualData() throws {
        let record = AttendanceRecord(
            workDate: makeDate(2026, 7, 4, 0, 0),
            checkIn: makeDate(2026, 7, 4, 10, 0),
            checkOut: makeDate(2026, 7, 4, 22, 0),
            actualCheckIn: makeDate(2026, 7, 4, 8, 30),
            actualCheckOut: makeDate(2026, 7, 4, 17, 10),
            actualDurationMinutes: 520,
            actualImportedAt: makeDate(2026, 7, 5, 9, 0),
            actualImportBatchID: UUID()
        )

        let backup = try BackupService.decode(
            try BackupService.jsonData(records: [record])
        )
        let restored = try XCTUnwrap(backup.records.first)

        XCTAssertEqual(backup.formatVersion, 3)
        XCTAssertEqual(restored.actualCheckIn, record.actualCheckIn)
        XCTAssertEqual(restored.actualCheckOut, record.actualCheckOut)
        XCTAssertEqual(restored.actualDurationMinutes, 520)
        XCTAssertEqual(
            restored.actualImportBatchID,
            record.actualImportBatchID
        )
    }

    private func row(
        date: Date,
        checkInMinute: Int,
        checkOutMinute: Int,
        duration: Int
    ) -> LabAttendanceImportRow {
        LabAttendanceImportRow(
            workDate: date,
            checkIn: AttendanceCalculator.date(
                on: date,
                minuteOfDay: checkInMinute,
                calendar: calendar
            ),
            checkOut: AttendanceCalculator.date(
                on: date,
                minuteOfDay: checkOutMinute,
                calendar: calendar
            ),
            durationMinutes: duration,
            reportedHours: Double(duration) / 60,
            lineNumber: 1
        )
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
