import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AttendanceStore
    @State private var selectedAnchor = Date.now
    @State private var editingDay: DaySelection?

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

            HStack(spacing: 14) {
                MetricTile(
                    title: "周期累计",
                    value: AttendanceCalculator.formatDuration(totalMinutes),
                    icon: "clock.fill",
                    color: .blue
                )
                MetricTile(
                    title: "已记录天数",
                    value: "\(periodRecords.filter(\.isComplete).count) 天",
                    icon: "calendar.badge.checkmark",
                    color: .green
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
            .padding(.horizontal, 28)
            .padding(.bottom, 18)

            List(days, id: \.self) { day in
                let record = store.record(on: day)
                Button {
                    editingDay = DaySelection(date: day)
                } label: {
                    DayRecordRow(day: day, record: record)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .sheet(item: $editingDay) { selection in
            ScrollView {
                TodayEditorView(
                    workDate: selection.date,
                    record: store.record(on: selection.date),
                    title: "编辑打卡记录"
                )
                .id(store.changeToken)
                .padding(24)
            }
            .environmentObject(store)
            .frame(width: 700, height: 560)
        }
    }
}

private struct DaySelection: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
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
                Text("\(DakaFormatters.time(record.checkIn)) — \(DakaFormatters.time(record.checkOut))")
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
