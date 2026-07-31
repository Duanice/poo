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
                    Text("\(DakaFormatters.time(today.checkIn)) — \(DakaFormatters.time(today.checkOut))")
                        .foregroundStyle(.secondary)
                    Text(AttendanceCalculator.compactDuration(today.durationMinutes))
                        .monospacedDigit()
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
                .disabled(store.todayRecord?.checkIn == nil)
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
