import SwiftUI
import WidgetKit

struct DakaAttendanceWidget: Widget {
    let kind = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DakaTimelineProvider()) { entry in
            DakaWidgetView(entry: entry)
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
        .description("显示本周期累计时长、今日状态并提供快捷打卡。")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        if family == .systemSmall {
            smallBody
        } else {
            mediumBody
        }
    }

    private var smallBody: some View {
        Link(destination: URL(string: "daka://today")!) {
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

                Text("今日 \(AttendanceCalculator.compactDuration(entry.todayMinutes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
    }

    private var mediumBody: some View {
        HStack(spacing: 18) {
            Link(destination: URL(string: "daka://today")!) {
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
                Text("\(DakaFormattersWidget.time(entry.todayCheckIn)) — \(DakaFormattersWidget.time(entry.todayCheckOut))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(AttendanceCalculator.formatDuration(entry.todayMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button(intent: QuickCheckInIntent()) {
                        Label("上班", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(intent: QuickCheckOutIntent()) {
                        Label("下班", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption)
            }
            .frame(width: 145, alignment: .leading)
        }
        .foregroundStyle(.white)
    }
}

private enum DakaFormattersWidget {
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

@main
struct DakaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DakaAttendanceWidget()
    }
}
