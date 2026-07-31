import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AttendanceStore

    @State private var targetHours: Double
    @State private var defaultStart: Date
    @State private var defaultEnd: Date
    @State private var checkInReminderEnabled: Bool
    @State private var checkInReminder: Date
    @State private var checkOutReminderEnabled: Bool
    @State private var checkOutReminder: Date
    @State private var savedMessage: String?

    init() {
        let settings = AppSettingsSnapshot.load()
        let today = Date.now
        _targetHours = State(initialValue: Double(settings.targetMinutes) / 60)
        _defaultStart = State(
            initialValue: AttendanceCalculator.date(
                on: today,
                minuteOfDay: settings.defaultStartMinute
            )
        )
        _defaultEnd = State(
            initialValue: AttendanceCalculator.date(
                on: today,
                minuteOfDay: settings.defaultEndMinute
            )
        )
        _checkInReminderEnabled = State(initialValue: settings.checkInReminderEnabled)
        _checkInReminder = State(
            initialValue: AttendanceCalculator.date(
                on: today,
                minuteOfDay: settings.checkInReminderMinute
            )
        )
        _checkOutReminderEnabled = State(initialValue: settings.checkOutReminderEnabled)
        _checkOutReminder = State(
            initialValue: AttendanceCalculator.date(
                on: today,
                minuteOfDay: settings.checkOutReminderMinute
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("设置")
                        .font(.largeTitle.bold())
                    Text("打卡周期固定为上月 25 日至本月 24 日。")
                        .foregroundStyle(.secondary)
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("周期与默认时间")
                            .font(.headline)

                        LabeledContent("每周期目标") {
                            HStack {
                                TextField("小时", value: $targetHours, format: .number.precision(.fractionLength(0...1)))
                                    .frame(width: 90)
                                    .multilineTextAlignment(.trailing)
                                Text("小时")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("默认上班时间") {
                            DatePicker(
                                "默认上班时间",
                                selection: $defaultStart,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }

                        LabeledContent("默认下班时间") {
                            DatePicker(
                                "默认下班时间",
                                selection: $defaultEnd,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("每日提醒")
                            .font(.headline)

                        HStack {
                            Toggle("上班提醒", isOn: $checkInReminderEnabled)
                            Spacer()
                            DatePicker(
                                "上班提醒时间",
                                selection: $checkInReminder,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .disabled(!checkInReminderEnabled)
                        }

                        HStack {
                            Toggle("下班提醒", isOn: $checkOutReminderEnabled)
                            Spacer()
                            DatePicker(
                                "下班提醒时间",
                                selection: $checkOutReminder,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .disabled(!checkOutReminderEnabled)
                        }

                        Text("提醒由 macOS 本地发送，不会上传任何数据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if let savedMessage {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("恢复默认值") {
                        restoreDefaults()
                    }
                    Button("保存设置") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func save() {
        guard targetHours > 0, targetHours <= 744 else {
            store.errorMessage = "周期目标必须大于 0 且不超过 744 小时。"
            return
        }
        let settings = AppSettingsSnapshot(
            targetMinutes: Int((targetHours * 60).rounded()),
            defaultStartMinute: AttendanceCalculator.minuteOfDay(from: defaultStart),
            defaultEndMinute: AttendanceCalculator.minuteOfDay(from: defaultEnd),
            checkInReminderEnabled: checkInReminderEnabled,
            checkInReminderMinute: AttendanceCalculator.minuteOfDay(from: checkInReminder),
            checkOutReminderEnabled: checkOutReminderEnabled,
            checkOutReminderMinute: AttendanceCalculator.minuteOfDay(from: checkOutReminder)
        )
        settings.save()
        store.refresh()

        Task {
            do {
                try await NotificationService.apply(settings: settings)
                await MainActor.run {
                    savedMessage = "设置已保存"
                }
            } catch {
                await MainActor.run {
                    store.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreDefaults() {
        targetHours = 160
        defaultStart = AttendanceCalculator.date(on: .now, minuteOfDay: 10 * 60)
        defaultEnd = AttendanceCalculator.date(on: .now, minuteOfDay: 22 * 60)
        checkInReminderEnabled = false
        checkInReminder = AttendanceCalculator.date(on: .now, minuteOfDay: 9 * 60 + 55)
        checkOutReminderEnabled = false
        checkOutReminder = AttendanceCalculator.date(on: .now, minuteOfDay: 21 * 60 + 55)
    }
}
