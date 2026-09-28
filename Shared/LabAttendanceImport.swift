import Foundation
import SwiftData

struct LabAttendanceImportRow: Identifiable, Sendable, Equatable {
    let workDate: Date
    let checkIn: Date
    let checkOut: Date
    let durationMinutes: Int
    let reportedHours: Double
    let lineNumber: Int

    var id: Date { workDate }
}

struct LabAttendanceImportDocument: Sendable, Equatable {
    let rows: [LabAttendanceImportRow]
    let reportedTotalMinutes: Int?
    let warnings: [String]

    var tableTotalMinutes: Int {
        rows.reduce(0) { $0 + $1.durationMinutes }
    }
}

enum LabAttendanceImportError: LocalizedError, Equatable {
    case emptyInput
    case noRows
    case invalidRows([String])
    case duplicateDates([String])

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "请先粘贴实验室发送的打卡邮件或表格。"
        case .noRows:
            return "没有识别到打卡明细。请确认每行包含日期、上班、下班和时长。"
        case let .invalidRows(messages):
            return "以下明细无法解析：\n\(messages.joined(separator: "\n"))"
        case let .duplicateDates(dates):
            return "同一批数据包含重复日期：\(dates.joined(separator: "、"))"
        }
    }
}

enum LabAttendanceImportParser {
    static func parse(
        _ input: String,
        calendar sourceCalendar: Calendar = .autoupdatingCurrent
    ) throws -> LabAttendanceImportDocument {
        let normalizedInput = input
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "／", with: "/")
        guard !normalizedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LabAttendanceImportError.emptyInput
        }

        let rowExpression = try NSRegularExpression(
            pattern: #"^\s*(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})\s+(\d{1,2}:\d{2})\s+(\d{1,2}:\d{2})\s+(\d+(?:\.\d+)?)\s*(?:小时|h)?\s*$"#,
            options: [.caseInsensitive]
        )
        var calendar = sourceCalendar
        calendar.locale = Locale(identifier: "zh_CN")

        var rows: [LabAttendanceImportRow] = []
        var invalidRows: [String] = []
        var warnings: [String] = []

        for (offset, originalLine) in normalizedInput.components(separatedBy: .newlines).enumerated() {
            let lineNumber = offset + 1
            let line = originalLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = rowExpression.firstMatch(
                in: line,
                options: [],
                range: fullRange
            ) else {
                if line.range(
                    of: #"^\s*\d{4}[-/.]\d{1,2}[-/.]\d{1,2}"#,
                    options: .regularExpression
                ) != nil {
                    invalidRows.append("第 \(lineNumber) 行：\(line)")
                }
                continue
            }

            func captured(_ index: Int) -> String {
                guard let range = Range(match.range(at: index), in: line) else {
                    return ""
                }
                return String(line[range])
            }

            do {
                let workDate = try parseDate(captured(1), calendar: calendar)
                let checkIn = try parseTime(
                    captured(2),
                    on: workDate,
                    calendar: calendar
                )
                var checkOut = try parseTime(
                    captured(3),
                    on: workDate,
                    calendar: calendar
                )
                if checkOut <= checkIn {
                    guard let nextDay = calendar.date(
                        byAdding: .day,
                        value: 1,
                        to: checkOut
                    ) else {
                        throw RowParseError.invalidTime
                    }
                    checkOut = nextDay
                }
                guard let hours = Double(captured(4)),
                      hours >= 0,
                      hours <= 24 else {
                    throw RowParseError.invalidDuration
                }

                let durationMinutes = Int((hours * 60).rounded())
                let calculatedMinutes = AttendanceCalculator.durationMinutes(
                    checkIn: checkIn,
                    checkOut: checkOut
                )
                if abs(durationMinutes - calculatedMinutes) > 6 {
                    warnings.append(
                        "第 \(lineNumber) 行官方时长与上下班时间相差 "
                            + "\(abs(durationMinutes - calculatedMinutes)) 分钟，将采用邮件中的官方时长。"
                    )
                }

                rows.append(
                    LabAttendanceImportRow(
                        workDate: workDate,
                        checkIn: checkIn,
                        checkOut: checkOut,
                        durationMinutes: durationMinutes,
                        reportedHours: hours,
                        lineNumber: lineNumber
                    )
                )
            } catch {
                invalidRows.append("第 \(lineNumber) 行：\(line)")
            }
        }

        guard invalidRows.isEmpty else {
            throw LabAttendanceImportError.invalidRows(invalidRows)
        }
        guard !rows.isEmpty else {
            throw LabAttendanceImportError.noRows
        }

        let groupedDates = Dictionary(grouping: rows, by: \.workDate)
        let duplicates = groupedDates
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
            .map(dateKey)
        guard duplicates.isEmpty else {
            throw LabAttendanceImportError.duplicateDates(duplicates)
        }

        let reportedTotalMinutes = extractReportedTotalMinutes(from: normalizedInput)
        let tableTotal = rows.reduce(0) { $0 + $1.durationMinutes }
        if let reportedTotalMinutes,
           abs(reportedTotalMinutes - tableTotal) > 3 {
            warnings.append(
                "邮件总计与明细合计相差 "
                    + "\(abs(reportedTotalMinutes - tableTotal)) 分钟，请在更新前核对。"
            )
        }

        return LabAttendanceImportDocument(
            rows: rows.sorted { $0.workDate < $1.workDate },
            reportedTotalMinutes: reportedTotalMinutes,
            warnings: warnings
        )
    }

    private enum RowParseError: Error {
        case invalidDate
        case invalidTime
        case invalidDuration
    }

    private static func parseDate(
        _ value: String,
        calendar: Calendar
    ) throws -> Date {
        let parts = value.split { "-/.".contains($0) }.compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(
                from: DateComponents(
                    year: parts[0],
                    month: parts[1],
                    day: parts[2]
                )
              ) else {
            throw RowParseError.invalidDate
        }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == parts[0],
              verified.month == parts[1],
              verified.day == parts[2] else {
            throw RowParseError.invalidDate
        }
        return calendar.startOfDay(for: date)
    }

    private static func parseTime(
        _ value: String,
        on date: Date,
        calendar: Calendar
    ) throws -> Date {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              (0...23).contains(parts[0]),
              (0...59).contains(parts[1]),
              let result = calendar.date(
                bySettingHour: parts[0],
                minute: parts[1],
                second: 0,
                of: date
              ) else {
            throw RowParseError.invalidTime
        }
        return result
    }

    private static func extractReportedTotalMinutes(from input: String) -> Int? {
        guard let expression = try? NSRegularExpression(
            pattern: #"(?:总计|合计)[^0-9]{0,24}(\d+(?:\.\d+)?)\s*小时"#,
            options: []
        ) else {
            return nil
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = expression.firstMatch(in: input, range: range),
              let valueRange = Range(match.range(at: 1), in: input),
              let hours = Double(input[valueRange]) else {
            return nil
        }
        return Int((hours * 60).rounded())
    }

    private static func dateKey(_ date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day],
            from: date
        )
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum LabAttendanceImportDisposition: String, Sendable {
    case newRecord
    case addActualData
    case updateActualData
    case unchanged

    var title: String {
        switch self {
        case .newRecord: "新增"
        case .addActualData: "补充实际数据"
        case .updateActualData: "更新实际数据"
        case .unchanged: "无变化"
        }
    }
}

struct LabAttendanceImportApplyResult: Sendable, Equatable {
    let created: Int
    let addedActualData: Int
    let updatedActualData: Int
    let unchanged: Int

    var changed: Int {
        created + addedActualData + updatedActualData
    }
}

enum LabAttendanceImportApplyError: LocalizedError, Equatable {
    case duplicateStoredDates([String])

    var errorDescription: String? {
        switch self {
        case let .duplicateStoredDates(dates):
            return "本地数据库中存在重复日期（\(dates.joined(separator: "、"))），"
                + "为避免覆盖错误，本次更新已取消。请先导出备份并处理重复记录。"
        }
    }
}

@MainActor
struct LabAttendanceImportService {
    let context: ModelContext
    let calendar: Calendar

    init(
        context: ModelContext,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.context = context
        self.calendar = calendar
    }

    func disposition(
        for row: LabAttendanceImportRow,
        existing: AttendanceRecord?
    ) -> LabAttendanceImportDisposition {
        guard let existing else { return .newRecord }
        guard existing.hasActualData else { return .addActualData }
        if existing.actualCheckIn == row.checkIn,
           existing.actualCheckOut == row.checkOut,
           existing.actualDurationMinutes == row.durationMinutes {
            return .unchanged
        }
        return .updateActualData
    }

    func apply(
        _ rows: [LabAttendanceImportRow],
        importedAt: Date = .now,
        batchID: UUID = UUID()
    ) throws -> LabAttendanceImportApplyResult {
        let existingRecords = try context.fetch(FetchDescriptor<AttendanceRecord>())
        let groupedRecords = Dictionary(grouping: existingRecords) {
            calendar.startOfDay(for: $0.workDate)
        }
        let duplicateDates = groupedRecords
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
            .map(formatDate)
        guard duplicateDates.isEmpty else {
            throw LabAttendanceImportApplyError.duplicateStoredDates(duplicateDates)
        }
        var recordsByDay = groupedRecords.mapValues { $0[0] }

        var created = 0
        var addedActualData = 0
        var updatedActualData = 0
        var unchanged = 0

        for row in rows {
            let day = calendar.startOfDay(for: row.workDate)
            let existing = recordsByDay[day]
            switch disposition(for: row, existing: existing) {
            case .newRecord:
                created += 1
            case .addActualData:
                addedActualData += 1
            case .updateActualData:
                updatedActualData += 1
            case .unchanged:
                unchanged += 1
                continue
            }

            let record = existing ?? AttendanceRecord(workDate: day)
            if existing == nil {
                context.insert(record)
                recordsByDay[day] = record
            }
            record.workDate = day
            record.actualCheckIn = row.checkIn
            record.actualCheckOut = row.checkOut
            record.actualDurationMinutes = row.durationMinutes
            record.actualImportedAt = importedAt
            record.actualImportBatchID = batchID
            record.isSlackingFlag = false
            record.isOffsiteStudyFlag = false
            record.updatedAt = importedAt
        }

        do {
            if created + addedActualData + updatedActualData > 0 {
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }

        return LabAttendanceImportApplyResult(
            created: created,
            addedActualData: addedActualData,
            updatedActualData: updatedActualData,
            unchanged: unchanged
        )
    }

    private func formatDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
