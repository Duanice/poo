import Foundation
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
        let period = AttendancePeriodCalculator.period(containing: now)
        let calendar = Calendar.autoupdatingCurrent

        do {
            let snapshot = try WidgetSnapshotStore.load()
            let records = snapshot.records.filter {
                period.contains($0.workDate)
            }
            let summaries = period.allDays(calendar: calendar).map { day in
                let record = records.first {
                    calendar.isDate($0.workDate, inSameDayAs: day)
                }
                return DailyAttendanceSummary(
                    date: day,
                    durationMinutes: record?.durationMinutes ?? 0,
                    isComplete: record?.isComplete ?? false,
                    isPartial: record != nil
                        && record?.isSlacking != true
                        && record?.isComplete != true
                        && (record?.checkIn != nil || record?.checkOut != nil),
                    isSlacking: record?.isSlacking ?? false
                )
            }
            let today = records.first {
                calendar.isDate($0.workDate, inSameDayAs: now)
            }
            let plan = CatchUpPlanCalculator.plan(
                period: period,
                summaries: summaries,
                targetMinutes: snapshot.targetMinutes,
                now: now,
                calendar: calendar
            )
            return DakaWidgetEntry(
                date: now,
                period: period,
                completedMinutes: plan.completedMinutes,
                targetMinutes: snapshot.targetMinutes,
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
                targetMinutes: AppConstants.defaultTargetMinutes,
                todayMinutes: 0,
                todayCheckIn: nil,
                todayCheckOut: nil,
                todayIsSlacking: false,
                catchUpPlan: CatchUpPlan(
                    completedMinutes: 0,
                    remainingMinutes: AppConstants.defaultTargetMinutes,
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
