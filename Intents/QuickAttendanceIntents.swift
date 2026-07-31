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
