import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AttendanceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("中关村实验室打卡")
                        .font(.largeTitle.bold())
                    Text("段冰洁 · \(DakaFormatters.period(store.currentPeriod))")
                        .foregroundStyle(.secondary)
                }

                ProgressSummaryCard(
                    period: store.currentPeriod,
                    completedMinutes: store.currentTotalMinutes,
                    targetMinutes: AppSettingsSnapshot.load().targetMinutes
                )

                TodayEditorView(
                    workDate: .now,
                    record: store.todayRecord,
                    title: "今日记录"
                )
                .id(store.changeToken)

                RecentRecordsCard()
            }
            .padding(28)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("概览")
    }
}

struct ProgressSummaryCard: View {
    let period: AttendancePeriod
    let completedMinutes: Int
    let targetMinutes: Int

    private var progress: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(completedMinutes) / Double(targetMinutes), 1)
    }

    private var remainingMinutes: Int {
        max(0, targetMinutes - completedMinutes)
    }

    private var remainingDays: Int {
        let today = Calendar.current.startOfDay(for: .now)
        guard today < period.endExclusive else { return 0 }
        return max(
            0,
            Calendar.current.dateComponents([.day], from: today, to: period.endExclusive).day ?? 0
        )
    }

    var body: some View {
        Card {
            HStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.16), lineWidth: 13)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.cyan, .blue, .indigo],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(.title2.bold())
                        Text("本周期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 126, height: 126)

                VStack(alignment: .leading, spacing: 12) {
                    Text("已完成")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(AttendanceCalculator.formatDuration(completedMinutes))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("/ \(AttendanceCalculator.formatDuration(targetMinutes))")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(.blue)
                    HStack(spacing: 12) {
                        StatusPill(
                            text: remainingMinutes == 0
                                ? "目标已完成"
                                : "还差 \(AttendanceCalculator.formatDuration(remainingMinutes))",
                            color: remainingMinutes == 0 ? .green : .blue
                        )
                        StatusPill(text: "剩余 \(remainingDays) 天", color: .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RecentRecordsCard: View {
    @EnvironmentObject private var store: AttendanceStore

    private var recentRecords: [AttendanceRecord] {
        Array(store.records.prefix(5))
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("最近记录")
                    .font(.headline)

                if recentRecords.isEmpty {
                    ContentUnavailableView(
                        "还没有打卡记录",
                        systemImage: "clock.badge.questionmark",
                        description: Text("保存今天的上下班时间后会显示在这里。")
                    )
                    .frame(minHeight: 120)
                } else {
                    ForEach(recentRecords) { record in
                        HStack(spacing: 14) {
                            Text(DakaFormatters.shortDay(record.workDate))
                                .font(.body.monospacedDigit())
                                .frame(width: 52, alignment: .leading)
                            Text("\(DakaFormatters.time(record.checkIn)) — \(DakaFormatters.time(record.checkOut))")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            StatusPill(text: record.statusText, color: record.statusColor)
                            Text(AttendanceCalculator.formatDuration(record.durationMinutes))
                                .font(.body.monospacedDigit())
                                .frame(width: 112, alignment: .trailing)
                        }
                        if record.id != recentRecords.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
