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
        if isComplete {
            return "已完成"
        }
        if checkIn != nil {
            return "进行中"
        }
        if checkOut != nil {
            return "待补上班"
        }
        return "未打卡"
    }

    var statusColor: Color {
        if isComplete { return .green }
        if checkIn != nil || checkOut != nil { return .orange }
        return .secondary
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
}
