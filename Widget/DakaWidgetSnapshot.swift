import Foundation
import SwiftData
import WidgetKit

struct DakaWidgetEntry: TimelineEntry {
    let date: Date
    let period: AttendancePeriod
    let completedMinutes: Int
    let targetMinutes: Int
    let todayMinutes: Int
    let todayCheckIn: Date?
    let todayCheckOut: Date?
    let loadError: Bool

    static var placeholder: DakaWidgetEntry {
        let period = AttendancePeriodCalculator.period(containing: .now)
        return DakaWidgetEntry(
            date: .now,
            period: period,
            completedMinutes: 92 * 60 + 30,
            targetMinutes: 160 * 60,
            todayMinutes: 8 * 60,
            todayCheckIn: AttendanceCalculator.date(on: .now, minuteOfDay: 10 * 60),
            todayCheckOut: AttendanceCalculator.date(on: .now, minuteOfDay: 18 * 60),
            loadError: false
        )
    }
}

enum DakaWidgetSnapshotLoader {
    static func load(at now: Date = .now) -> DakaWidgetEntry {
        let settings = AppSettingsSnapshot.load()
        let period = AttendancePeriodCalculator.period(containing: now)

        do {
            let container = try AppDataContainer.make()
            let context = ModelContext(container)
            let start = period.start
            let end = period.endExclusive
            let descriptor = FetchDescriptor<AttendanceRecord>(
                predicate: #Predicate { record in
                    record.workDate >= start && record.workDate < end
                }
            )
            let records = try context.fetch(descriptor)
            let today = records.first {
                Calendar.autoupdatingCurrent.isDate($0.workDate, inSameDayAs: now)
            }
            return DakaWidgetEntry(
                date: now,
                period: period,
                completedMinutes: records
                    .filter { $0.workDate <= now }
                    .reduce(0) { $0 + $1.durationMinutes },
                targetMinutes: settings.targetMinutes,
                todayMinutes: today?.durationMinutes ?? 0,
                todayCheckIn: today?.checkIn,
                todayCheckOut: today?.checkOut,
                loadError: false
            )
        } catch {
            return DakaWidgetEntry(
                date: now,
                period: period,
                completedMinutes: 0,
                targetMinutes: settings.targetMinutes,
                todayMinutes: 0,
                todayCheckIn: nil,
                todayCheckOut: nil,
                loadError: true
            )
        }
    }
}

struct DakaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DakaWidgetEntry {
        .placeholder
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DakaWidgetEntry) -> Void
    ) {
        completion(context.isPreview ? .placeholder : DakaWidgetSnapshotLoader.load())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DakaWidgetEntry>) -> Void
    ) {
        let entry = DakaWidgetSnapshotLoader.load()
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: 15,
            to: .now
        ) ?? Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
