import Foundation
@preconcurrency import UserNotifications

enum NotificationService {
    private static let checkInID = "daka.reminder.checkin"
    private static let checkOutID = "daka.reminder.checkout"

    static func apply(settings: AppSettingsSnapshot) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [checkInID, checkOutID])

        guard settings.checkInReminderEnabled || settings.checkOutReminderEnabled else {
            return
        }

        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else {
            throw NotificationError.permissionDenied
        }

        if settings.checkInReminderEnabled {
            try await schedule(
                center: center,
                identifier: checkInID,
                title: "上班打卡提醒",
                body: "记得记录今天的上班时间。",
                minuteOfDay: settings.checkInReminderMinute
            )
        }

        if settings.checkOutReminderEnabled {
            try await schedule(
                center: center,
                identifier: checkOutID,
                title: "下班打卡提醒",
                body: "今天辛苦了，记得完成下班打卡。",
                minuteOfDay: settings.checkOutReminderMinute
            )
        }
    }

    private static func schedule(
        center: UNUserNotificationCenter,
        identifier: String,
        title: String,
        body: String,
        minuteOfDay: Int
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        try await center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
        )
    }
}

enum NotificationError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "通知权限未开启。请在“系统设置 → 通知”中允许本应用发送通知。"
    }
}
