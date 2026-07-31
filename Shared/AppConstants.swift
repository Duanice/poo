import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.duanice.daka"
    static let widgetKind = "DakaAttendanceWidget"
    static let defaultTargetMinutes = 160 * 60
    static let defaultStartMinute = 10 * 60
    static let defaultEndMinute = 22 * 60
    static let cycleStartDay = 25
}

enum SettingsKeys {
    static let targetMinutes = "settings.targetMinutes"
    static let defaultStartMinute = "settings.defaultStartMinute"
    static let defaultEndMinute = "settings.defaultEndMinute"
    static let checkInReminderEnabled = "settings.checkInReminderEnabled"
    static let checkInReminderMinute = "settings.checkInReminderMinute"
    static let checkOutReminderEnabled = "settings.checkOutReminderEnabled"
    static let checkOutReminderMinute = "settings.checkOutReminderMinute"
    static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
}

struct AppSettingsSnapshot: Sendable, Equatable {
    var targetMinutes: Int
    var defaultStartMinute: Int
    var defaultEndMinute: Int
    var checkInReminderEnabled: Bool
    var checkInReminderMinute: Int
    var checkOutReminderEnabled: Bool
    var checkOutReminderMinute: Int

    static func load() -> AppSettingsSnapshot {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        defaults.register(defaults: [
            SettingsKeys.targetMinutes: AppConstants.defaultTargetMinutes,
            SettingsKeys.defaultStartMinute: AppConstants.defaultStartMinute,
            SettingsKeys.defaultEndMinute: AppConstants.defaultEndMinute,
            SettingsKeys.checkInReminderEnabled: false,
            SettingsKeys.checkInReminderMinute: 9 * 60 + 55,
            SettingsKeys.checkOutReminderEnabled: false,
            SettingsKeys.checkOutReminderMinute: 21 * 60 + 55
        ])
        return AppSettingsSnapshot(
            targetMinutes: max(1, defaults.integer(forKey: SettingsKeys.targetMinutes)),
            defaultStartMinute: defaults.integer(forKey: SettingsKeys.defaultStartMinute),
            defaultEndMinute: defaults.integer(forKey: SettingsKeys.defaultEndMinute),
            checkInReminderEnabled: defaults.bool(forKey: SettingsKeys.checkInReminderEnabled),
            checkInReminderMinute: defaults.integer(forKey: SettingsKeys.checkInReminderMinute),
            checkOutReminderEnabled: defaults.bool(forKey: SettingsKeys.checkOutReminderEnabled),
            checkOutReminderMinute: defaults.integer(forKey: SettingsKeys.checkOutReminderMinute)
        )
    }

    func save() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
        defaults.set(targetMinutes, forKey: SettingsKeys.targetMinutes)
        defaults.set(defaultStartMinute, forKey: SettingsKeys.defaultStartMinute)
        defaults.set(defaultEndMinute, forKey: SettingsKeys.defaultEndMinute)
        defaults.set(checkInReminderEnabled, forKey: SettingsKeys.checkInReminderEnabled)
        defaults.set(checkInReminderMinute, forKey: SettingsKeys.checkInReminderMinute)
        defaults.set(checkOutReminderEnabled, forKey: SettingsKeys.checkOutReminderEnabled)
        defaults.set(checkOutReminderMinute, forKey: SettingsKeys.checkOutReminderMinute)
    }
}
