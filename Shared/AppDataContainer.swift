import Foundation
import SwiftData

enum AppDataContainer {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([AttendanceRecord.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "DakaTest",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "Daka",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier(AppConstants.appGroupIdentifier),
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
