import AppKit
import SwiftUI

struct LabAttendanceImportView: View {
    @EnvironmentObject private var store: AttendanceStore

    @State private var rawText = ""
    @State private var document: LabAttendanceImportDocument?
    @State private var selectedDates: Set<Date> = []
    @State private var inlineError: String?
    @State private var resultMessage: String?
    @State private var showingApplyConfirmation = false

    private var previewItems: [PreviewItem] {
        guard let document else { return [] }
        let service = LabAttendanceImportService(context: store.modelContext)
        return document.rows.map { row in
            let existing = store.record(on: row.workDate)
            return PreviewItem(
                row: row,
                existing: existing,
                disposition: service.disposition(for: row, existing: existing)
            )
        }
    }

    private var selectedRows: [LabAttendanceImportRow] {
        previewItems.compactMap { item in
            selectedDates.contains(item.row.workDate) ? item.row : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                inputCard

                if let inlineError {
                    errorCard(inlineError)
                }

                if let document {
                    summaryCard(document)
                    previewCard
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                }
            }
            .padding(28)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog(
            "确认更新实验室实际数据",
            isPresented: $showingApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("备份并更新 \(selectedRows.count) 天") {
                applySelectedRows()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("更新前会自动创建完整 JSON 备份。手动记录不会被删除，统计将优先采用实验室实际数据。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("实际数据批量更新")
                .font(.largeTitle.bold())
            Text("粘贴实验室周报，核对差异后按日期合并实际打卡数据。")
                .foregroundStyle(.secondary)
        }
    }

    private var inputCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("粘贴邮件或表格", systemImage: "doc.on.clipboard")
                        .font(.headline)
                    Spacer()
                    Button("从剪贴板粘贴") {
                        pasteFromClipboard()
                    }
                    Button("清空") {
                        reset()
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $rawText)
                        .font(.body.monospaced())
                        .frame(minHeight: 190)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(
                            .quaternary.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 10)
                        )

                    if rawText.isEmpty {
                        Text("可直接粘贴完整邮件，或粘贴“日期 上班 下班 时长（小时）”表格。")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Label(
                        "支持制表符、多个空格、全角冒号，以及跨午夜下班时间。",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("解析并预览") {
                        parseInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
    }

    private func summaryCard(_ document: LabAttendanceImportDocument) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ImportMetricTile(
                        title: "识别明细",
                        value: "\(document.rows.count) 天",
                        icon: "list.bullet.clipboard.fill",
                        color: .blue
                    )
                    ImportMetricTile(
                        title: "邮件总计",
                        value: document.reportedTotalMinutes.map(hoursText) ?? "未提供",
                        icon: "envelope.badge.fill",
                        color: .purple
                    )
                    ImportMetricTile(
                        title: "明细合计",
                        value: hoursText(document.tableTotalMinutes),
                        icon: "sum",
                        color: .cyan
                    )
                }

                if document.reportedTotalMinutes == nil {
                    warningRow("未从正文识别到“总计 X 小时”，请重点核对明细合计。")
                }
                ForEach(document.warnings, id: \.self) { warning in
                    warningRow(warning)
                }
            }
        }
    }

    private var previewCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("更新预览")
                            .font(.headline)
                        Text("新周报缺少的日期不会被删除；无变化日期默认不选中。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("选择全部变化") {
                        selectedDates = Set(
                            previewItems
                                .filter { $0.disposition != .unchanged }
                                .map(\.row.workDate)
                        )
                    }
                    Button("取消全选") {
                        selectedDates.removeAll()
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Text("")
                        .frame(width: 24)
                    Text("日期")
                        .frame(width: 92, alignment: .leading)
                    Text("实验室周报")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("当前有效记录")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("操作")
                        .frame(width: 112, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(previewItems) { item in
                    previewRow(item)
                    if item.id != previewItems.last?.id {
                        Divider()
                    }
                }

                HStack {
                    Text("已选择 \(selectedRows.count) 天")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("备份并应用更新") {
                        showingApplyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRows.isEmpty)
                }
                .padding(.top, 4)
            }
        }
    }

    private func previewRow(_ item: PreviewItem) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { selectedDates.contains(item.row.workDate) },
                    set: { selected in
                        if selected {
                            selectedDates.insert(item.row.workDate)
                        } else {
                            selectedDates.remove(item.row.workDate)
                        }
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(item.disposition == .unchanged)
            .frame(width: 24)

            Text(dateText(item.row.workDate))
                .font(.body.monospacedDigit())
                .frame(width: 92, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "\(DakaFormatters.time(item.row.checkIn)) — "
                        + "\(DakaFormatters.time(item.row.checkOut))"
                )
                .monospacedDigit()
                Text(hoursText(item.row.durationMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let existing = item.existing {
                    Text(
                        "\(DakaFormatters.time(existing.effectiveCheckIn)) — "
                            + "\(DakaFormatters.time(existing.effectiveCheckOut))"
                    )
                    .monospacedDigit()
                    Text(
                        "\(hoursText(existing.durationMinutes)) · "
                            + (existing.hasActualData ? "实验室实际" : "手动记录")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("无记录")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StatusPill(
                text: item.disposition.title,
                color: dispositionColor(item.disposition)
            )
            .frame(width: 112, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func errorCard(_ message: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .textSelection(.enabled)
            }
        }
    }

    private func warningRow(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.orange)
    }

    private func parseInput() {
        do {
            let parsed = try LabAttendanceImportParser.parse(rawText)
            document = parsed
            inlineError = nil
            resultMessage = nil
            let service = LabAttendanceImportService(context: store.modelContext)
            selectedDates = Set(
                parsed.rows.compactMap { row in
                    service.disposition(
                        for: row,
                        existing: store.record(on: row.workDate)
                    ) == .unchanged ? nil : row.workDate
                }
            )
        } catch {
            document = nil
            selectedDates.removeAll()
            resultMessage = nil
            inlineError = error.localizedDescription
        }
    }

    private func applySelectedRows() {
        do {
            let result = try store.importLabAttendance(selectedRows)
            selectedDates.removeAll()
            inlineError = nil
            resultMessage = "更新完成：新增 \(result.created) 天，补充 \(result.addedActualData) 天，"
                + "修正 \(result.updatedActualData) 天。"
        } catch {
            inlineError = "批量更新失败：\(error.localizedDescription)"
        }
    }

    private func pasteFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string) else {
            inlineError = "剪贴板中没有可粘贴的文字。"
            return
        }
        rawText = value
        parseInput()
    }

    private func reset() {
        rawText = ""
        document = nil
        selectedDates.removeAll()
        inlineError = nil
        resultMessage = nil
    }

    private func hoursText(_ minutes: Int) -> String {
        String(format: "%.1f 小时", Double(minutes) / 60)
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    private func dispositionColor(
        _ disposition: LabAttendanceImportDisposition
    ) -> Color {
        switch disposition {
        case .newRecord: .green
        case .addActualData: .blue
        case .updateActualData: .orange
        case .unchanged: .secondary
        }
    }
}

private struct PreviewItem: Identifiable {
    let row: LabAttendanceImportRow
    let existing: AttendanceRecord?
    let disposition: LabAttendanceImportDisposition

    var id: Date { row.workDate }
}

private struct ImportMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
