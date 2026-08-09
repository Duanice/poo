import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupRecord: Codable, Sendable {
    let id: UUID
    let workDate: Date
    let checkIn: Date?
    let checkOut: Date?
    let note: String
    let isSlacking: Bool?
    let createdAt: Date
    let updatedAt: Date
    let actualCheckIn: Date?
    let actualCheckOut: Date?
    let actualDurationMinutes: Int?
    let actualImportedAt: Date?
    let actualImportBatchID: UUID?

    init(record: AttendanceRecord) {
        id = record.id
        workDate = record.workDate
        checkIn = record.checkIn
        checkOut = record.checkOut
        note = record.note
        isSlacking = record.isSlacking
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        actualCheckIn = record.actualCheckIn
        actualCheckOut = record.actualCheckOut
        actualDurationMinutes = record.actualDurationMinutes
        actualImportedAt = record.actualImportedAt
        actualImportBatchID = record.actualImportBatchID
    }
}

struct BackupEnvelope: Codable, Sendable {
    let formatVersion: Int
    let exportedAt: Date
    let appName: String
    let records: [BackupRecord]

    init(records: [AttendanceRecord]) {
        formatVersion = 3
        exportedAt = .now
        appName = "中关村实验室打卡 for 段冰洁"
        self.records = records.map(BackupRecord.init)
    }
}

enum BackupService {
    static func jsonData(records: [AttendanceRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BackupEnvelope(records: records))
    }

    static func decode(_ data: Data) throws -> BackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard (1...3).contains(envelope.formatVersion) else {
            throw BackupError.unsupportedVersion(envelope.formatVersion)
        }
        return envelope
    }

    static func csvData(records: [AttendanceRecord]) -> Data {
        var lines = [
            "日期,数据来源,实际上班,实际下班,官方时长（分钟）,"
                + "手动上班,手动下班,有效时长（分钟）,有效时长,记录状态,备注"
        ]
        let ordered = records.sorted { $0.workDate < $1.workDate }
        for record in ordered {
            let columns = [
                record.workDate.formatted(.iso8601.year().month().day()),
                record.hasActualData ? "实验室实际数据" : "手动记录",
                DakaFormatters.time(record.actualCheckIn),
                DakaFormatters.time(record.actualCheckOut),
                record.actualDurationMinutes.map(String.init) ?? "",
                DakaFormatters.time(record.checkIn),
                DakaFormatters.time(record.checkOut),
                String(record.durationMinutes),
                AttendanceCalculator.formatDuration(record.durationMinutes),
                record.statusText,
                record.note
            ].map(csvEscape)
            lines.append(columns.joined(separator: ","))
        }
        return ("\u{FEFF}" + lines.joined(separator: "\n"))
            .data(using: .utf8) ?? Data()
    }

    static func writeAutomaticBackup(records: [AttendanceRecord]) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appending(path: "com.duanice.daka", directoryHint: .isDirectory)
            .appending(path: "Backups", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appending(
            path: "auto-\(DakaFormatters.exportTimestamp())-"
                + "\(UUID().uuidString.prefix(8)).daka-backup.json"
        )
        try jsonData(records: records).write(to: url, options: .atomic)
        return url
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "不支持版本为 \(version) 的备份文件。"
        }
    }
}

struct DakaExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json, .commaSeparatedText]
    }

    let data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
