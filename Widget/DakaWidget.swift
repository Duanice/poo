import SwiftUI
import WidgetKit

struct DakaAttendanceWidget: Widget {
    let kind = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DakaTimelineProvider()) { entry in
            DakaWidgetView(entry: entry)
                .environment(\.calendar, DakaCalendar.china)
                .environment(\.timeZone, DakaCalendar.timeZone)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.12, blue: 0.22),
                            Color(red: 0.08, green: 0.19, blue: 0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("打卡周期")
        .description("显示周期日历、累计时长、追赶计划并提供快捷打卡。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct DakaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DakaWidgetEntry

    private var progress: Double {
        min(
            Double(entry.completedMinutes) / Double(max(entry.targetMinutes, 1)),
            1
        )
    }

    var body: some View {
        if entry.loadError {
            snapshotErrorBody
        } else {
            switch family {
            case .systemSmall:
                smallBody
            case .systemMedium:
                mediumBody
            default:
                largeBody
            }
        }
    }

    private var snapshotErrorBody: some View {
        Link(destination: URL(string: "poo://sync")!) {
            VStack(alignment: .leading, spacing: 10) {
                Label("打卡数据待同步", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                Text("打开一次主应用即可恢复桌面组件数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Label("打开主应用", systemImage: "arrow.up.forward.app")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    private var smallBody: some View {
        Link(destination: URL(string: "poo://today")!) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("打卡", systemImage: "clock.badge.checkmark.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                }

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(AttendanceCalculator.compactDuration(entry.completedMinutes))
                            .font(.title3.bold().monospacedDigit())
                        Text("/ \(AttendanceCalculator.compactDuration(entry.targetMinutes))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(todayCompactText)
                    Spacer()
                    Text(catchUpCompactText)
                }
                .font(.caption2)
                .foregroundStyle(todayStatusColor)
            }
        }
        .foregroundStyle(.white)
    }

    private var mediumBody: some View {
        HStack(spacing: 18) {
            Link(destination: URL(string: "poo://today")!) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("中关村实验室打卡", systemImage: "clock.badge.checkmark.fill")
                        .font(.headline)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(AttendanceCalculator.compactDuration(entry.completedMinutes))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("/ \(AttendanceCalculator.compactDuration(entry.targetMinutes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: progress)
                        .tint(.cyan)

                    Text(
                        "\(DakaFormattersWidget.shortDate(entry.period.start))—\(DakaFormattersWidget.shortDate(entry.period.endInclusive))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("今日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(todayTimeText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(todayDurationText)
                    .font(.caption)
                    .foregroundStyle(todayStatusColor)

                Text(catchUpText)
                    .font(.caption2)
                    .foregroundStyle(catchUpColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Link(destination: URL(string: "poo://quick/check-in")!) {
                        Label("上班", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Link(destination: URL(string: "poo://quick/check-out")!) {
                        Label("下班", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Link(destination: URL(string: "poo://quick/toggle-slacking")!) {
                        Image(systemName: entry.todayIsSlacking ? "arrow.uturn.backward" : "moon.zzz.fill")
                    }
                    .buttonStyle(.bordered)
                    .help(entry.todayIsSlacking ? "取消今日摆烂" : "今天摆烂")
                }
                .font(.caption2)
            }
            .frame(width: 145, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("中关村实验室打卡", systemImage: "clock.badge.checkmark.fill")
                        .font(.headline)
                    Text(
                        "\(DakaFormattersWidget.shortDate(entry.period.start))—\(DakaFormattersWidget.shortDate(entry.period.endInclusive))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(AttendanceCalculator.compactDuration(entry.completedMinutes))
                        .font(.title2.bold().monospacedDigit())
                    Text("/ \(AttendanceCalculator.compactDuration(entry.targetMinutes)) · \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(.cyan)

            DakaCycleGrid(
                summaries: entry.dailySummaries,
                today: entry.date
            )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(catchUpText)
                        .font(.caption.bold())
                        .foregroundStyle(catchUpColor)
                    Text(todayDetailText)
                    .font(.caption2)
                    .foregroundStyle(todayStatusColor)
                }

                Spacer()

                HStack(spacing: 8) {
                    Link(destination: URL(string: "poo://quick/check-in")!) {
                        Label("上班", systemImage: "play.fill")
                    }
                    Link(destination: URL(string: "poo://quick/check-out")!) {
                        Label("下班", systemImage: "stop.fill")
                    }
                    Link(destination: URL(string: "poo://quick/toggle-slacking")!) {
                        Label(
                            entry.todayIsSlacking ? "取消摆烂" : "摆烂",
                            systemImage: entry.todayIsSlacking ? "arrow.uturn.backward" : "moon.zzz.fill"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption2)
            }
        }
        .foregroundStyle(.white)
    }

    private var catchUpText: String {
        if entry.catchUpPlan.isCompleted {
            return "本周期目标已完成"
        }
        if entry.catchUpPlan.isImpossible {
            return "无剩余可打卡日期，还差 \(AttendanceCalculator.compactDuration(entry.catchUpPlan.remainingMinutes))"
        }
        return "剩余 \(entry.catchUpPlan.eligibleDays) 天 · 每天需 \(AttendanceCalculator.compactDuration(entry.catchUpPlan.requiredMinutesPerDay))"
    }

    private var todayCompactText: String {
        if entry.todayIsSlacking { return "今日摆烂" }
        if entry.todayIsOffsiteStudy { return "今日外出自习" }
        return "今日 \(AttendanceCalculator.compactDuration(entry.todayMinutes))"
    }

    private var todayTimeText: String {
        if entry.todayIsSlacking { return "今日摆烂" }
        if entry.todayIsOffsiteStudy { return "今日外出自习" }
        return "\(DakaFormattersWidget.time(entry.todayCheckIn)) — \(DakaFormattersWidget.time(entry.todayCheckOut))"
    }

    private var todayDurationText: String {
        entry.todayIsSlacking || entry.todayIsOffsiteStudy
            ? "不计入打卡时长"
            : AttendanceCalculator.formatDuration(entry.todayMinutes)
    }

    private var todayDetailText: String {
        if entry.todayIsSlacking { return "今日已设为摆烂日" }
        if entry.todayIsOffsiteStudy { return "今日外出自习 · 不计打卡时长" }
        return "今日 \(DakaFormattersWidget.time(entry.todayCheckIn))—"
            + "\(DakaFormattersWidget.time(entry.todayCheckOut)) · "
            + AttendanceCalculator.compactDuration(entry.todayMinutes)
    }

    private var todayStatusColor: Color {
        if entry.todayIsSlacking { return .purple }
        if entry.todayIsOffsiteStudy { return .green }
        return .secondary
    }

    private var catchUpCompactText: String {
        if entry.catchUpPlan.isCompleted {
            return "已达标"
        }
        if entry.catchUpPlan.isImpossible {
            return "无法达标"
        }
        return "日均 \(AttendanceCalculator.compactDuration(entry.catchUpPlan.requiredMinutesPerDay))"
    }

    private var catchUpColor: Color {
        switch entry.catchUpPlan.loadLevel {
        case .completed:
            return .green
        case .normal:
            return .cyan
        case .warning:
            return .orange
        case .critical, .impossible:
            return .red
        }
    }
}

private struct DakaCycleGrid: View {
    let summaries: [DailyAttendanceSummary]
    let today: Date

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 26), spacing: 5),
        count: 7
    )

    private var paddedSummaries: [DailyAttendanceSummary?] {
        guard let firstDate = summaries.first?.date else {
            return []
        }
        let weekday = DakaCalendar.china.component(.weekday, from: firstDate)
        let leadingEmptyDays = (weekday + 5) % 7
        return Array(repeating: nil, count: leadingEmptyDays) + summaries.map(Optional.some)
    }

    var body: some View {
        VStack(spacing: 5) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(paddedSummaries.enumerated()), id: \.offset) { _, summary in
                    if let summary {
                        DakaCycleDay(summary: summary, today: today)
                    } else {
                        Color.clear
                            .frame(height: 31)
                    }
                }
            }

            HStack(spacing: 11) {
                DakaGridLegend(color: .blue, text: "已完成")
                DakaGridLegend(color: .orange, text: "未完整")
                DakaGridLegend(color: .green, text: "外出自习")
                DakaGridLegend(color: .purple, text: "摆烂")
                DakaGridLegend(color: .white.opacity(0.18), text: "未记录")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DakaCycleDay: View {
    let summary: DailyAttendanceSummary
    let today: Date

    private var fillColor: Color {
        if summary.isSlacking {
            return .purple.opacity(0.75)
        }
        if summary.isOffsiteStudy {
            return .green.opacity(0.75)
        }
        if summary.isComplete {
            return .blue.opacity(0.75)
        }
        if summary.isPartial {
            return .orange.opacity(0.75)
        }
        return .white.opacity(0.08)
    }

    var body: some View {
        Link(destination: DakaFormattersWidget.recordURL(summary.date)) {
            VStack(spacing: 1) {
                Text(DakaFormattersWidget.dayNumber(summary.date))
                    .font(.caption2.bold().monospacedDigit())
                if summary.durationMinutes > 0 {
                    Text(AttendanceCalculator.compactDuration(summary.durationMinutes))
                        .font(.system(size: 7, weight: .medium, design: .rounded))
                        .lineLimit(1)
                } else {
                    Image(
                        systemName: summary.isSlacking
                            ? "moon.zzz.fill"
                            : summary.isOffsiteStudy ? "book.closed.fill" : "minus"
                    )
                        .font(.system(size: 7))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 29)
            .background(fillColor, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                if DakaCalendar.china.isDate(summary.date, inSameDayAs: today) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.cyan, lineWidth: 1.5)
                }
            }
        }
    }
}

private struct DakaGridLegend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

private enum DakaFormattersWidget {
    private static var chinaStyle: Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: DakaCalendar.locale,
            calendar: DakaCalendar.china,
            timeZone: DakaCalendar.timeZone
        )
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(chinaStyle.month(.twoDigits).day(.twoDigits))
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(
            chinaStyle.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        )
    }

    static func dayNumber(_ date: Date) -> String {
        String(DakaCalendar.china.component(.day, from: date))
    }

    static func recordURL(_ date: Date) -> URL {
        let components = DakaCalendar.china.dateComponents(
            [.year, .month, .day],
            from: date
        )
        let value = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return URL(string: "poo://record/\(value)")!
    }
}

@main
struct DakaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DakaAttendanceWidget()
    }
}
