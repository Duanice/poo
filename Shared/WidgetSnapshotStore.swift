import Darwin
import Foundation

struct WidgetSnapshotRecord: Codable, Sendable, Equatable {
    let workDate: Date
    let checkIn: Date?
    let checkOut: Date?
    let isSlacking: Bool

    var durationMinutes: Int {
        guard !isSlacking else { return 0 }
        return AttendanceCalculator.durationMinutes(
            checkIn: checkIn,
            checkOut: checkOut
        )
    }

    var isComplete: Bool {
        !isSlacking
            && checkIn != nil
            && checkOut != nil
            && durationMinutes > 0
    }
}

struct WidgetSnapshotDocument: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let targetMinutes: Int
    let records: [WidgetSnapshotRecord]
}

enum WidgetSnapshotStore {
    enum SnapshotError: LocalizedError {
        case homeDirectoryUnavailable
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .homeDirectoryUnavailable:
                return "无法确定当前用户目录。"
            case let .unsupportedSchema(version):
                return "桌面组件数据版本不受支持（\(version)）。"
            }
        }
    }

    private static let directoryComponents = [
        "Library",
        "Application Support",
        "com.duanice.daka"
    ]
    private static let fileName = "widget-snapshot-v1.json"

    static func write(
        records: [AttendanceRecord],
        settings: AppSettingsSnapshot,
        now: Date = .now
    ) throws {
        let document = WidgetSnapshotDocument(
            schemaVersion: WidgetSnapshotDocument.currentSchemaVersion,
            generatedAt: now,
            targetMinutes: max(1, settings.targetMinutes),
            records: records.map {
                WidgetSnapshotRecord(
                    workDate: $0.workDate,
                    checkIn: $0.checkIn,
                    checkOut: $0.checkOut,
                    isSlacking: $0.isSlacking
                )
            }
        )

        let directoryURL = try snapshotDirectoryURL()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try encoder.encode(document).write(
            to: fileURL,
            options: .atomic
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    static func load() throws -> WidgetSnapshotDocument {
        let data = try Data(
            contentsOf: try snapshotDirectoryURL()
                .appendingPathComponent(fileName)
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(WidgetSnapshotDocument.self, from: data)
        guard document.schemaVersion == WidgetSnapshotDocument.currentSchemaVersion else {
            throw SnapshotError.unsupportedSchema(document.schemaVersion)
        }
        return document
    }

    private static func snapshotDirectoryURL() throws -> URL {
        guard let passwordEntry = getpwuid(getuid()),
              let homePointer = passwordEntry.pointee.pw_dir else {
            throw SnapshotError.homeDirectoryUnavailable
        }
        let homeURL = URL(
            fileURLWithPath: String(cString: homePointer),
            isDirectory: true
        )
        return directoryComponents.reduce(homeURL) { partialURL, component in
            partialURL.appendingPathComponent(component, isDirectory: true)
        }
    }
}
