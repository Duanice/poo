import AppIntents

@available(macOS 15.0, *)
struct QuickCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "现在上班"
    static let description = IntentDescription("使用当前时间记录上班打卡。")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
        .result(
            opensIntent: OpenURLIntent(URL(string: "poo://quick/check-in")!),
            dialog: "正在打开打卡应用并记录上班时间"
        )
    }
}

@available(macOS 15.0, *)
struct QuickCheckOutIntent: AppIntent {
    static let title: LocalizedStringResource = "现在下班"
    static let description = IntentDescription("使用当前时间完成今天的下班打卡。")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
        .result(
            opensIntent: OpenURLIntent(URL(string: "poo://quick/check-out")!),
            dialog: "正在打开打卡应用并记录下班时间"
        )
    }
}

@available(macOS 15.0, *)
struct ToggleTodaySlackingIntent: AppIntent {
    static let title: LocalizedStringResource = "切换今日摆烂"
    static let description = IntentDescription("将今天设为摆烂日，或取消今天的摆烂状态。")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
        .result(
            opensIntent: OpenURLIntent(URL(string: "poo://quick/toggle-slacking")!),
            dialog: "正在打开打卡应用并切换今日摆烂状态"
        )
    }
}
