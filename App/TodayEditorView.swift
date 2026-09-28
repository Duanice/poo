import SwiftUI

struct TodayEditorView: View {
    @EnvironmentObject private var store: AttendanceStore

    let workDate: Date
    let record: AttendanceRecord?
    let title: String
    let onFinished: (() -> Void)?

    @State private var hasCheckIn: Bool
    @State private var hasCheckOut: Bool
    @State private var checkInTime: Date
    @State private var checkOutTime: Date
    @State private var crossesMidnight: Bool
    @State private var note: String
    @State private var savedMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showSlackingConfirmation = false
    @State private var showOffsiteStudyConfirmation = false
    @State private var showClearActualConfirmation = false

    init(
        workDate: Date,
        record: AttendanceRecord?,
        title: String,
        onFinished: (() -> Void)? = nil
    ) {
        self.workDate = workDate
        self.record = record
        self.title = title
        self.onFinished = onFinished

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

                if let record, record.hasActualData {
                    HStack(spacing: 14) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("实验室实际数据")
                                .font(.headline)
                            Text(
                                "\(DakaFormatters.time(record.actualCheckIn)) — "
                                    + "\(DakaFormatters.time(record.actualCheckOut)) · "
                                    + "\(AttendanceCalculator.formatDuration(record.durationMinutes))"
                            )
                            .font(.body.monospacedDigit())
                            Text("统计、日历和桌面组件优先采用该数据；下方仍保留你的手动记录。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("移除实际数据", role: .destructive) {
                            showClearActualConfirmation = true
                        }
                    }
                    .padding(14)
                    .background(.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                }

                if record?.isSlacking == true {
                    HStack(spacing: 16) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.purple)
                            .frame(width: 58, height: 58)
                            .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("该日期已设为摆烂日")
                                .font(.headline)
                            Text("不计打卡时长，也不计入剩余可打卡日期。")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("取消摆烂并编辑") {
                            _ = store.setSlacking(on: workDate, enabled: false)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    HStack {
                        Spacer()
                        Button("删除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                } else if record?.isOffsiteStudy == true {
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                            .frame(width: 58, height: 58)
                            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("该日期已设为外出自习")
                                .font(.headline)
                            Text("不计打卡时长，也不计入剩余可打卡日期。")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("取消外出自习并编辑") {
                            _ = store.setOffsiteStudy(on: workDate, enabled: false)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    HStack {
                        Spacer()
                        Button("删除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                } else {
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
                        Text("日期状态")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(
                            Calendar.current.isDateInToday(workDate)
                                ? "今天外出自习"
                                : "设为外出自习"
                        ) {
                            if store.requiresClearingBeforeOffsiteStudy(on: workDate) {
                                showOffsiteStudyConfirmation = true
                            } else if store.setOffsiteStudy(on: workDate, enabled: true) {
                                onFinished?()
                            }
                        }
                        .tint(.green)

                        Button(Calendar.current.isDateInToday(workDate) ? "今天摆烂" : "设为摆烂日") {
                            if store.requiresClearingBeforeSlacking(on: workDate) {
                                showSlackingConfirmation = true
                            } else if store.setSlacking(on: workDate, enabled: true) {
                                onFinished?()
                            }
                        }
                        .tint(.purple)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record?.hasActualData == true ? "手动记录时长" : "当日有效时长")
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
                    } else if record?.hasActualData == true {
                        Label(
                            "修改并保存手动记录不会覆盖实验室实际数据。",
                            systemImage: "building.2"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .confirmationDialog(
            "确定删除 \(DakaFormatters.shortDay(workDate)) 的打卡记录吗？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                if store.delete(on: workDate) {
                    onFinished?()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "该日期已经存在打卡时间",
            isPresented: $showSlackingConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空记录并摆烂", role: .destructive) {
                if store.setSlacking(
                    on: workDate,
                    enabled: true,
                    clearExistingRecord: true
                ) {
                    onFinished?()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已有的手动与实验室实际时间将被清空，但可以通过反馈提示中的“撤销”恢复。")
        }
        .confirmationDialog(
            "该日期已经存在打卡时间",
            isPresented: $showOffsiteStudyConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空记录并设为外出自习", role: .destructive) {
                if store.setOffsiteStudy(
                    on: workDate,
                    enabled: true,
                    clearExistingRecord: true
                ) {
                    onFinished?()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已有的手动与实验室实际时间将被清空，但可以通过反馈提示中的“撤销”恢复。")
        }
        .confirmationDialog(
            "确定移除 \(DakaFormatters.shortDay(workDate)) 的实验室实际数据吗？",
            isPresented: $showClearActualConfirmation,
            titleVisibility: .visible
        ) {
            Button("移除实际数据", role: .destructive) {
                if store.clearActualData(on: workDate) {
                    onFinished?()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("移除后统计将恢复采用该日期的手动记录，并可通过反馈中的“撤销”恢复。")
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
            onFinished?()
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
