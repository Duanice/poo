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
    let todayIsSlacking: Bool
    let catchUpPlan: CatchUpPlan
    let dailySummaries: [DailyAttendanceSummary]
    let loadError: Bool

    static var placeholder: DakaWidgetEntry {
        let period = AttendancePeriodCalculator.period(containing: .now)
        let summaries = period.allDays().enumerated().map { index, date in
            DailyAttendanceSummary(
                date: date,
                durationMinutes: index < 10 ? (6 + index % 5) * 60 : 0,
                isComplete: index < 10,
                isPartial: index == 10,
                isSlacking: index == 11 || index == 14
            )
        }
        return DakaWidgetEntry(
            date: .now,
            period: period,
            completedMinutes: 92 * 60 + 30,
            targetMinutes: 160 * 60,
            todayMinutes: 8 * 60,
            todayCheckIn: AttendanceCalculator.date(on: .now, minuteOfDay: 10 * 60),
            todayCheckOut: AttendanceCalculator.date(on: .now, minuteOfDay: 18 * 60),
            todayIsSlacking: false,
            catchUpPlan: CatchUpPlan(
                completedMinutes: 92 * 60 + 30,
                remainingMinutes: 67 * 60 + 30,
                eligibleDays: 8,
                requiredMinutesPerDay: 507,
                loadLevel: .normal
            ),
            dailySummaries: summaries,
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
            let summaries = AttendanceSummaryBuilder.make(
                period: period,
                records: records
            )
            let today = records.first {
                Calendar.autoupdatingCurrent.isDate($0.workDate, inSameDayAs: now)
            }
            let plan = CatchUpPlanCalculator.plan(
                period: period,
                summaries: summaries,
                targetMinutes: settings.targetMinutes,
                now: now
            )
            return DakaWidgetEntry(
                date: now,
                period: period,
                completedMinutes: plan.completedMinutes,
                targetMinutes: settings.targetMinutes,
                todayMinutes: today?.durationMinutes ?? 0,
                todayCheckIn: today?.checkIn,
                todayCheckOut: today?.checkOut,
                todayIsSlacking: today?.isSlacking ?? false,
                catchUpPlan: plan,
                dailySummaries: summaries,
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
                todayIsSlacking: false,
                catchUpPlan: CatchUpPlan(
                    completedMinutes: 0,
                    remainingMinutes: settings.targetMinutes,
                    eligibleDays: 0,
                    requiredMinutesPerDay: 0,
                    loadLevel: .impossible
                ),
                dailySummaries: [],
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
