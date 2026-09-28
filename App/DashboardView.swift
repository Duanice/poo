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
                    targetMinutes: AppSettingsSnapshot.load().targetMinutes,
                    offsiteStudyDays: store.currentPeriodRecords.filter(\.isOffsiteStudy).count
                )

                CatchUpPlanCard()

                TodayEditorView(
                    workDate: .now,
                    record: store.todayRecord,
                    title: "今日记录"
                )
                .id(store.changeToken)

                Card {
                    CycleCalendarView(
                        period: store.currentPeriod,
                        compact: true
                    )
                }

                RecentRecordsCard()
            }
            .padding(28)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("概览")
    }
}

struct CatchUpPlanCard: View {
    @EnvironmentObject private var store: AttendanceStore
    @State private var showClearConfirmation = false
    @State private var showOffsiteStudyClearConfirmation = false

    private var plan: CatchUpPlan {
        store.currentCatchUpPlan
    }

    private var accentColor: Color {
        switch plan.loadLevel {
        case .completed: .green
        case .normal: .blue
        case .warning: .orange
        case .critical, .impossible: .red
        }
    }

    private var headline: String {
        if plan.isCompleted {
            return "本周期目标已完成"
        }
        if plan.isImpossible {
            return "当前计划无法完成"
        }
        return "每天需要 \(AttendanceCalculator.formatDuration(plan.requiredMinutesPerDay))"
    }

    var body: some View {
        Card {
            HStack(spacing: 18) {
                Image(systemName: plan.isCompleted ? "flag.checkered.circle.fill" : "figure.run.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(accentColor)
                    .frame(width: 58, height: 58)
                    .background(accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 5) {
                    Text("追赶计划")
                        .font(.headline)
                    Text(headline)
                        .font(.title3.bold().monospacedDigit())
                    if plan.isCompleted {
                        Text("已完成 \(AttendanceCalculator.formatDuration(plan.completedMinutes))")
                            .foregroundStyle(.secondary)
                    } else if plan.isImpossible {
                        Text("还差 \(AttendanceCalculator.formatDuration(plan.remainingMinutes))，但已无剩余可打卡日期。")
                            .foregroundStyle(.red)
                    } else {
                        Text(
                            "还差 \(AttendanceCalculator.formatDuration(plan.remainingMinutes)) · 剩余 \(plan.eligibleDays) 个可打卡日"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        if store.todayRecord?.isOffsiteStudy == true {
                            _ = store.setOffsiteStudy(on: .now, enabled: false)
                        } else if store.requiresClearingBeforeOffsiteStudy(on: .now) {
                            showOffsiteStudyClearConfirmation = true
                        } else {
                            _ = store.setOffsiteStudy(on: .now, enabled: true)
                        }
                    } label: {
                        Label(
                            store.todayRecord?.isOffsiteStudy == true
                                ? "取消外出自习"
                                : "今天外出自习",
                            systemImage: store.todayRecord?.isOffsiteStudy == true
                                ? "arrow.uturn.backward"
                                : "book.closed.fill"
                        )
                    }
                    .tint(.green)

                    Button {
                        if store.todayRecord?.isSlacking == true {
                            _ = store.setSlacking(on: .now, enabled: false)
                        } else if store.requiresClearingBeforeSlacking(on: .now) {
                            showClearConfirmation = true
                        } else {
                            _ = store.setSlacking(on: .now, enabled: true)
                        }
                    } label: {
                        Label(
                            store.todayRecord?.isSlacking == true ? "取消今日摆烂" : "今天摆烂",
                            systemImage: store.todayRecord?.isSlacking == true
                                ? "arrow.uturn.backward"
                                : "moon.zzz.fill"
                        )
                    }
                    .tint(.purple)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .confirmationDialog(
            "今天已经存在打卡记录",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空记录并摆烂", role: .destructive) {
                _ = store.setSlacking(
                    on: .now,
                    enabled: true,
                    clearExistingRecord: true
                )
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已有的上下班时间将被清空，可以通过反馈提示中的“撤销”恢复。")
        }
        .confirmationDialog(
            "今天已经存在打卡记录",
            isPresented: $showOffsiteStudyClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空记录并设为外出自习", role: .destructive) {
                _ = store.setOffsiteStudy(
                    on: .now,
                    enabled: true,
                    clearExistingRecord: true
                )
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已有的上下班时间将被清空，可以通过反馈提示中的“撤销”恢复。")
        }
    }
}

struct ProgressSummaryCard: View {
    let period: AttendancePeriod
    let completedMinutes: Int
    let targetMinutes: Int
    let offsiteStudyDays: Int

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
                        StatusPill(text: "外出自习 \(offsiteStudyDays) 天", color: .green)
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
                            Text(
                                "\(DakaFormatters.time(record.effectiveCheckIn)) — "
                                    + "\(DakaFormatters.time(record.effectiveCheckOut))"
                            )
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
