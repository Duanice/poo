import SwiftUI

struct TodayEditorView: View {
    @EnvironmentObject private var store: AttendanceStore

    let workDate: Date
    let record: AttendanceRecord?
    let title: String

    @State private var hasCheckIn: Bool
    @State private var hasCheckOut: Bool
    @State private var checkInTime: Date
    @State private var checkOutTime: Date
    @State private var crossesMidnight: Bool
    @State private var note: String
    @State private var savedMessage: String?
    @State private var showDeleteConfirmation = false

    init(workDate: Date, record: AttendanceRecord?, title: String) {
        self.workDate = workDate
        self.record = record
        self.title = title

        let settings = AppSettingsSnapshot.load()
        let defaultCheckIn = AttendanceCalculator.date(
            on: workDate,
            minuteOfDay: settings.defaultStartMinute
        )
        let defaultCheckOut = AttendanceCalculator.date(
            on: workDate,
            minuteOfDay: settings.defaultEndMinute
        )
        let isCrossing = {
            guard let checkOut = record?.checkOut else { return false }
            return !Calendar.current.isDate(checkOut, inSameDayAs: workDate)
        }()

        _hasCheckIn = State(initialValue: record == nil || record?.checkIn != nil)
        _hasCheckOut = State(initialValue: record == nil || record?.checkOut != nil)
        _checkInTime = State(initialValue: record?.checkIn ?? defaultCheckIn)
        _checkOutTime = State(initialValue: record?.checkOut ?? defaultCheckOut)
        _crossesMidnight = State(initialValue: isCrossing)
        _note = State(initialValue: record?.note ?? "")
    }

    private var proposedCheckIn: Date? {
        guard hasCheckIn else { return nil }
        return AttendanceCalculator.date(
            on: workDate,
            minuteOfDay: AttendanceCalculator.minuteOfDay(from: checkInTime)
        )
    }

    private var proposedCheckOut: Date? {
        guard hasCheckOut else { return nil }
        return AttendanceCalculator.date(
            on: workDate,
            minuteOfDay: AttendanceCalculator.minuteOfDay(from: checkOutTime),
            dayOffset: crossesMidnight ? 1 : 0
        )
    }

    private var proposedDuration: Int {
        AttendanceCalculator.durationMinutes(
            checkIn: proposedCheckIn,
            checkOut: proposedCheckOut
        )
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                        Text(DakaFormatters.day(workDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let record {
                        StatusPill(text: record.statusText, color: record.statusColor)
                    } else {
                        StatusPill(text: "尚未保存", color: .secondary)
                    }
                }

                HStack(spacing: 18) {
                    TimeField(
                        title: "上班时间",
                        enabled: $hasCheckIn,
                        selection: $checkInTime,
                        tint: .cyan
                    )
                    TimeField(
                        title: "下班时间",
                        enabled: $hasCheckOut,
                        selection: $checkOutTime,
                        tint: .indigo
                    )
                }

                Toggle("下班时间跨至次日", isOn: $crossesMidnight)
                    .disabled(!hasCheckOut)

                TextField("备注（可选）", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当日有效时长")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AttendanceCalculator.formatDuration(proposedDuration))
                            .font(.title3.bold().monospacedDigit())
                    }

                    Spacer()

                    if let savedMessage {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }

                    if record != nil {
                        Button("删除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }

                    Button("现在上班") {
                        store.checkInNow()
                    }
                    .disabled(!Calendar.current.isDateInToday(workDate))

                    Button("现在下班") {
                        store.checkOutNow()
                    }
                    .disabled(!Calendar.current.isDateInToday(workDate))

                    Button("保存记录") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if record == nil {
                    Label(
                        "10:00 和 22:00 是建议值；只有点击“保存记录”后才会计入时长。",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "确定删除 \(DakaFormatters.shortDay(workDate)) 的打卡记录吗？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                store.delete(on: workDate)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func save() {
        if store.save(
            workDate: workDate,
            checkIn: proposedCheckIn,
            checkOut: proposedCheckOut,
            note: note
        ) {
            withAnimation {
                savedMessage = "已保存"
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation {
                        savedMessage = nil
                    }
                }
            }
        }
    }
}

private struct TimeField: View {
    let title: String
    @Binding var enabled: Bool
    @Binding var selection: Date
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(title, isOn: $enabled)
                    .toggleStyle(.checkbox)
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }
            DatePicker(
                title,
                selection: $selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.field)
            .disabled(!enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}
