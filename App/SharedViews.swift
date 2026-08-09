import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

extension AttendanceRecord {
    var statusText: String {
        if isSlacking {
            return "摆烂"
        }
        if hasActualData {
            return "实验室实际"
        }
        if isComplete {
            return "已完成"
        }
        if effectiveCheckIn != nil {
            return "进行中"
        }
        if effectiveCheckOut != nil {
            return "待补上班"
        }
        return "未打卡"
    }

    var statusColor: Color {
        if isSlacking { return .purple }
        if hasActualData { return .cyan }
        if isComplete { return .green }
        if hasAnyEffectiveTime { return .orange }
        return .secondary
    }
}

struct FeedbackBanner: View {
    @EnvironmentObject private var store: AttendanceStore
    let feedback: AppFeedback

    private var color: Color {
        switch feedback.style {
        case .success: .green
        case .information: .purple
        case .warning: .orange
        case .failure: .red
        }
    }

    private var icon: String {
        switch feedback.style {
        case .success: "checkmark.circle.fill"
        case .information: "moon.zzz.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = feedback.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if feedback.actionTitle != nil {
                Button(feedback.actionTitle ?? "撤销") {
                    store.undoLastChange()
                }
                .buttonStyle(.bordered)
            }
            Button {
                store.dismissFeedback()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.32))
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}

struct RecordEditorSheet: View {
    @EnvironmentObject private var store: AttendanceStore
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    store.editRequest = nil
                } label: {
                    Label("关闭", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            ScrollView {
                TodayEditorView(
                    workDate: date,
                    record: store.record(on: date),
                    title: "编辑打卡记录",
                    onFinished: {
                        store.editRequest = nil
                    }
                )
                .id(store.changeToken)
                .padding(24)
            }
        }
        .frame(width: 700, height: 590)
    }
}

enum DakaFormatters {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().weekday(.abbreviated).locale(Locale(identifier: "zh_CN")))
    }

    static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN")))
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "zh_CN")))
    }

    static func period(_ period: AttendancePeriod) -> String {
        let start = period.start.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        let end = period.endInclusive.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        return "\(start) — \(end)"
    }

    static func exportTimestamp(_ date: Date = .now) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d%02d%02d-%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        )
    }

    static func deepLinkDate(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
