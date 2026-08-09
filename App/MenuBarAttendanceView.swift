import AppKit
import SwiftUI

struct MenuBarAttendanceView: View {
    @EnvironmentObject private var store: AttendanceStore
    @Environment(\.openWindow) private var openWindow

    private var targetMinutes: Int {
        AppSettingsSnapshot.load().targetMinutes
    }

    private var progress: Double {
        min(Double(store.currentTotalMinutes) / Double(max(targetMinutes, 1)), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("中关村实验室打卡")
                    .font(.headline)
                Text(DakaFormatters.period(store.currentPeriod))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(AttendanceCalculator.formatDuration(store.currentTotalMinutes))
                        .font(.title3.bold().monospacedDigit())
                    Spacer()
                    Text("/ \(AttendanceCalculator.formatDuration(targetMinutes))")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(.blue)
            }

            if let today = store.todayRecord {
                HStack {
                    Text("今日")
                    Spacer()
                    if today.isSlacking {
                        Label("摆烂", systemImage: "moon.zzz.fill")
                            .foregroundStyle(.purple)
                    } else {
                        Text(
                            "\(DakaFormatters.time(today.effectiveCheckIn)) — "
                                + "\(DakaFormatters.time(today.effectiveCheckOut))"
                        )
                            .foregroundStyle(.secondary)
                        Text(AttendanceCalculator.compactDuration(today.durationMinutes))
                            .monospacedDigit()
                    }
                }
            } else {
                Text("今日尚未打卡")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("现在上班") {
                    store.checkInNow()
                }
                Button("现在下班") {
                    store.checkOutNow()
                }
                .disabled(
                    store.todayRecord?.checkIn == nil
                        || store.todayRecord?.isSlacking == true
                )
                Button(store.todayRecord?.isSlacking == true ? "取消摆烂" : "今天摆烂") {
                    if store.todayRecord?.isSlacking == true {
                        _ = store.setSlacking(on: .now, enabled: false)
                    } else if !store.requiresClearingBeforeSlacking(on: .now) {
                        _ = store.setSlacking(on: .now, enabled: true)
                    } else {
                        openWindow(id: "main")
                        store.openEditor(on: .now)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .tint(.purple)
            }

            let plan = store.currentCatchUpPlan
            if !plan.isCompleted {
                HStack {
                    Text("追赶计划")
                    Spacer()
                    if plan.isImpossible {
                        Text("已无可打卡日")
                            .foregroundStyle(.red)
                    } else {
                        Text("剩 \(plan.eligibleDays) 天 · 每天 \(AttendanceCalculator.compactDuration(plan.requiredMinutesPerDay))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Divider()

            HStack {
                Button("打开完整记录") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
