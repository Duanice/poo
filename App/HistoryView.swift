import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AttendanceStore
    @State private var selectedAnchor = Date.now
    @State private var listExpanded = false

    private var period: AttendancePeriod {
        AttendancePeriodCalculator.period(containing: selectedAnchor)
    }

    private var periodRecords: [AttendanceRecord] {
        store.records(in: period)
    }

    private var totalMinutes: Int {
        periodRecords.reduce(0) { $0 + $1.durationMinutes }
    }

    private var days: [Date] {
        period.allDays().reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("历史记录")
                        .font(.largeTitle.bold())
                    Text(DakaFormatters.period(period))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    selectedAnchor = Calendar.current.date(
                        byAdding: .month,
                        value: -1,
                        to: period.start
                    )!
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button("本周期") {
                    selectedAnchor = .now
                }
                Button {
                    selectedAnchor = Calendar.current.date(
                        byAdding: .month,
                        value: 1,
                        to: period.start
                    )!
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(28)

            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 14) {
                        MetricTile(
                            title: "周期累计",
                            value: AttendanceCalculator.formatDuration(totalMinutes),
                            icon: "clock.fill",
                            color: .blue
                        )
                        MetricTile(
                            title: "已完成记录",
                            value: "\(periodRecords.filter(\.isComplete).count) 天",
                            icon: "calendar.badge.checkmark",
                            color: .green
                        )
                        MetricTile(
                            title: "摆烂日",
                            value: "\(periodRecords.filter(\.isSlacking).count) 天",
                            icon: "moon.zzz.fill",
                            color: .purple
                        )
                        MetricTile(
                            title: "距目标",
                            value: AttendanceCalculator.formatDuration(
                                max(0, AppSettingsSnapshot.load().targetMinutes - totalMinutes)
                            ),
                            icon: "flag.checkered",
                            color: .orange
                        )
                    }

                    Card {
                        CycleCalendarView(period: period)
                    }

                    Card {
                        DisclosureGroup("列表视图", isExpanded: $listExpanded) {
                            VStack(spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    let record = store.record(on: day)
                                    Button {
                                        store.openEditor(on: day)
                                    } label: {
                                        DayRecordRow(day: day, record: record)
                                    }
                                    .buttonStyle(.plain)
                                    if day != days.last {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.top, 12)
                        }
                        .font(.headline)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct CalendarDateSelection: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}

struct CycleCalendarView: View {
    @EnvironmentObject private var store: AttendanceStore
    let period: AttendancePeriod
    var compact = false

    @State private var pendingSlackingDate: CalendarDateSelection?

    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]
    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 54), spacing: 8),
        count: 7
    )

    private var gridDays: [Date?] {
        let days = period.allDays()
        guard let first = days.first else { return [] }
        let weekday = Calendar.current.component(.weekday, from: first)
        let leadingEmpty = (weekday + 5) % 7
        var result = Array<Date?>(repeating: nil, count: leadingEmpty)
        result.append(contentsOf: days.map(Optional.some))
        let trailingEmpty = (7 - result.count % 7) % 7
        result.append(contentsOf: Array(repeating: nil, count: trailingEmpty))
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("周期日历")
                        .font(.headline)
                    Text("点击日期编辑，点击月亮图标一键设置摆烂")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CalendarLegend(color: .blue, text: "已完成")
                CalendarLegend(color: .cyan, text: "实验室实际")
                CalendarLegend(color: .orange, text: "进行中")
                CalendarLegend(color: .purple, text: "摆烂")
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdayNames, id: \.self) { name in
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDayCell(
                            day: day,
                            record: store.record(on: day),
                            bowelMovementCount: store.bowelMovementCount(on: day),
                            compact: compact,
                            onOpen: {
                                store.openEditor(on: day)
                            },
                            onToggleSlacking: {
                                toggleSlacking(on: day)
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: compact ? 62 : 82)
                    }
                }
            }
        }
        .confirmationDialog(
            "该日期已经存在打卡时间",
            isPresented: Binding(
                get: { pendingSlackingDate != nil },
                set: { if !$0 { pendingSlackingDate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("清空记录并摆烂", role: .destructive) {
                if let date = pendingSlackingDate?.date {
                    _ = store.setSlacking(
                        on: date,
                        enabled: true,
                        clearExistingRecord: true
                    )
                }
                pendingSlackingDate = nil
            }
            Button("取消", role: .cancel) {
                pendingSlackingDate = nil
            }
        } message: {
            Text("已有的上下班时间将被清空，可以通过反馈提示中的“撤销”恢复。")
        }
    }

    private func toggleSlacking(on date: Date) {
        if store.record(on: date)?.isSlacking == true {
            _ = store.setSlacking(on: date, enabled: false)
        } else if store.requiresClearingBeforeSlacking(on: date) {
            pendingSlackingDate = CalendarDateSelection(date: date)
        } else {
            _ = store.setSlacking(on: date, enabled: true)
        }
    }
}

private struct CalendarLegend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CalendarDayCell: View {
    let day: Date
    let record: AttendanceRecord?
    let bowelMovementCount: Int
    let compact: Bool
    let onOpen: () -> Void
    let onToggleSlacking: () -> Void

    private var backgroundColor: Color {
        if record?.isSlacking == true {
            return .purple.opacity(0.18)
        }
        if record?.hasActualData == true {
            return .cyan.opacity(0.22)
        }
        if record?.isComplete == true {
            let intensity = min(
                max(Double(record?.durationMinutes ?? 0) / Double(12 * 60), 0.25),
                1
            )
            return .blue.opacity(0.12 + intensity * 0.28)
        }
        if record?.hasAnyEffectiveTime == true {
            return .orange.opacity(0.16)
        }
        return .secondary.opacity(0.06)
    }

    private var detail: String {
        if record?.isSlacking == true {
            return "摆烂"
        }
        if record?.isComplete == true {
            return AttendanceCalculator.compactDuration(record?.durationMinutes ?? 0)
        }
        if record?.hasAnyEffectiveTime == true {
            return "进行中"
        }
        return "未记录"
    }

    private var timeRange: String? {
        guard let record, record.hasAnyEffectiveTime else { return nil }
        return "\(DakaFormatters.time(record.effectiveCheckIn))–"
            + DakaFormatters.time(record.effectiveCheckOut)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: compact ? 3 : 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(dayLabel)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        if bowelMovementCount > 0 {
                            Text(bowelBadge)
                                .font(.caption2)
                                .accessibilityLabel("当天粑粑 \(bowelMovementCount) 次")
                        }
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    if let timeRange {
                        Text(timeRange)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    HStack(spacing: 4) {
                        if record?.isSlacking == true {
                            Image(systemName: "moon.zzz.fill")
                        } else if record?.hasActualData == true {
                            Image(systemName: "building.2.fill")
                        } else if record?.isComplete == true {
                            Image(systemName: "checkmark.circle.fill")
                        } else if record?.hasAnyEffectiveTime == true {
                            Image(systemName: "clock.badge.exclamationmark")
                        }
                        Text(detail)
                            .lineLimit(1)
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(record?.isSlacking == true ? .purple : .secondary)
                    if !compact, record?.note.isEmpty == false {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, minHeight: compact ? 62 : 82, alignment: .leading)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    if Calendar.current.isDateInToday(day) {
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(.cyan, lineWidth: 2)
                    }
                }
                .opacity(day > Date.now ? 0.72 : 1)
            }
            .buttonStyle(.plain)

            Button(action: onToggleSlacking) {
                Image(systemName: record?.isSlacking == true ? "moon.zzz.fill" : "moon.zzz")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .padding(7)
            }
            .buttonStyle(.plain)
            .help(record?.isSlacking == true ? "取消摆烂" : "设为摆烂日")
        }
    }

    private var dayLabel: String {
        if Calendar.current.component(.day, from: day) == 1 {
            return day.formatted(
                .dateTime
                    .month(.abbreviated)
                    .day()
                    .locale(Locale(identifier: "zh_CN"))
            )
        }
        return day.formatted(.dateTime.day())
    }

    private var bowelBadge: String {
        if bowelMovementCount <= 3 {
            return String(repeating: "💩", count: bowelMovementCount)
        }
        return "💩×\(bowelMovementCount)"
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DayRecordRow: View {
    let day: Date
    let record: AttendanceRecord?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.month().day()))
                    .font(.body.weight(.semibold))
                Text(day.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN"))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, alignment: .leading)

            if let record {
                Text(
                    "\(DakaFormatters.time(record.effectiveCheckIn)) — "
                        + "\(DakaFormatters.time(record.effectiveCheckOut))"
                )
                    .font(.body.monospacedDigit())
                    .frame(width: 150, alignment: .leading)
                StatusPill(text: record.statusText, color: record.statusColor)
                if !record.note.isEmpty {
                    Label(record.note, systemImage: "note.text")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(AttendanceCalculator.formatDuration(record.durationMinutes))
                    .font(.body.weight(.semibold).monospacedDigit())
            } else {
                Text("未记录")
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("0 分钟")
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}
