import AppIntents
import SwiftData
import WidgetKit

struct QuickCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "现在上班"
    static let description = IntentDescription("使用当前时间记录上班打卡。")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try AppDataContainer.make()
            let context = ModelContext(container)
            try AttendanceMutationService(context: context).checkInNow()
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
            return .result(dialog: "上班时间已记录")
        } catch {
            return .result(
                dialog: IntentDialog(stringLiteral: "记录失败：\(error.localizedDescription)")
            )
        }
    }
}

struct QuickCheckOutIntent: AppIntent {
    static let title: LocalizedStringResource = "现在下班"
    static let description = IntentDescription("使用当前时间完成今天的下班打卡。")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try AppDataContainer.make()
            let context = ModelContext(container)
            try AttendanceMutationService(context: context).checkOutNow()
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
            return .result(dialog: "下班时间已记录")
        } catch {
            return .result(
                dialog: IntentDialog(stringLiteral: "记录失败：\(error.localizedDescription)")
            )
        }
    }
}

struct ToggleTodaySlackingIntent: AppIntent {
    static let title: LocalizedStringResource = "切换今日摆烂"
    static let description = IntentDescription("将今天设为摆烂日，或取消今天的摆烂状态。")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try AppDataContainer.make()
            let context = ModelContext(container)
            let service = AttendanceMutationService(context: context)
            let today = try service.record(on: .now)
            let willEnable = today?.isSlacking != true

            if willEnable && (today?.checkIn != nil || today?.checkOut != nil) {
                return .result(dialog: "今天已有打卡记录，请打开主应用确认清空后再摆烂。")
            }

            try service.setSlacking(on: .now, enabled: willEnable)
            let period = AttendancePeriodCalculator.period(containing: .now)
            let start = period.start
            let end = period.endExclusive
            let records = try context.fetch(
                FetchDescriptor<AttendanceRecord>(
                    predicate: #Predicate { record in
                        record.workDate >= start && record.workDate < end
                    }
                )
            )
            let summaries = AttendanceSummaryBuilder.make(
                period: period,
                records: records
            )
            let plan = CatchUpPlanCalculator.plan(
                period: period,
                summaries: summaries,
                targetMinutes: AppSettingsSnapshot.load().targetMinutes
            )
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)

            if willEnable {
                let detail = plan.isImpossible
                    ? "今天已摆烂，本周期已无剩余可打卡日期。"
                    : "今天已摆烂，剩余 \(plan.eligibleDays) 天每天需要 \(AttendanceCalculator.formatDuration(plan.requiredMinutesPerDay))。"
                return .result(dialog: IntentDialog(stringLiteral: detail))
            }
            return .result(
                dialog: IntentDialog(
                    stringLiteral: "已取消今日摆烂，剩余 \(plan.eligibleDays) 天每天需要 \(AttendanceCalculator.formatDuration(plan.requiredMinutesPerDay))。"
                )
            )
        } catch {
            return .result(
                dialog: IntentDialog(stringLiteral: "操作失败：\(error.localizedDescription)")
            )
        }
    }
}
