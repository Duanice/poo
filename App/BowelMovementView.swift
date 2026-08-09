import SwiftUI
import UniformTypeIdentifiers

struct BowelMovementView: View {
    @EnvironmentObject private var store: AttendanceStore

    @State private var quickNote = ""
    @State private var selectedDate = Date.now
    @State private var editorRequest: BowelMovementEditorRequest?
    @State private var pendingDeletion: BowelMovementRecord?
    @State private var exportDocument = DakaExportDocument()
    @State private var showingExporter = false

    private var selectedRecords: [BowelMovementRecord] {
        store.bowelMovements(on: selectedDate)
    }

    private var selectedStatus: BowelDayStatus {
        store.bowelDayStatus(on: selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("粑粑记录")
                        .font(.largeTitle.bold())
                    Text("每次排便单独记录；同一天可以记录多次。")
                        .foregroundStyle(.secondary)
                }

                quickRecordCard
                managementCard
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editorRequest) { request in
            BowelMovementEditorSheet(request: request)
                .environmentObject(store)
        }
        .confirmationDialog(
            "确定删除这条粑粑记录吗？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                if let pendingDeletion {
                    _ = store.deleteBowelMovement(id: pendingDeletion.id)
                }
                self.pendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("删除后无法撤销；完整备份仍可用于恢复。")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "daka-bowel-records-\(DakaFormatters.exportTimestamp())"
        ) { result in
            if case let .failure(error) = result {
                store.errorMessage = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    private var quickRecordCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("粑粑了吗？")
                            .font(.title2.bold())
                        Text(todayStatusText)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("💩")
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                }

                TextField("描述（可选，例如状态、感受）", text: $quickNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                HStack {
                    Text("描述最多 500 字")
                        .font(.caption)
                        .foregroundStyle(quickNote.count > 500 ? .red : .secondary)
                    Spacer()
                    Button("记录一次 💩") {
                        if store.saveBowelMovement(
                            occurredAt: .now,
                            note: quickNote
                        ) {
                            quickNote = ""
                            selectedDate = .now
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickNote.count > 500)
                }
            }
        }
    }

    private var managementCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("数据管理")
                            .font(.headline)
                        Text("补录、修改或删除任意一天的单次记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        moveSelectedDate(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button("今天") {
                        selectedDate = .now
                    }
                    Button {
                        moveSelectedDate(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    DatePicker(
                        "查看日期",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                }

                statusBanner
                Divider()

                if selectedRecords.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptyIcon,
                        description: Text(emptyDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    VStack(spacing: 0) {
                        ForEach(selectedRecords) { record in
                            bowelMovementRow(record)
                            if record.id != selectedRecords.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                HStack {
                    Button("导出全部粑粑 CSV") {
                        exportDocument = DakaExportDocument(
                            data: BackupService.bowelCSVData(
                                records: store.bowelMovements
                            )
                        )
                        showingExporter = true
                    }
                    Spacer()
                    Button("补录一次") {
                        editorRequest = .new(on: selectedDate)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedStatus == .future)
                }
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Text(statusEmoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(DakaFormatters.day(selectedDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(13)
        .background(statusColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private func bowelMovementRow(_ record: BowelMovementRecord) -> some View {
        HStack(spacing: 14) {
            Text("💩")
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(DakaFormatters.time(record.occurredAt))
                    .font(.body.weight(.semibold).monospacedDigit())
                Text(record.note.isEmpty ? "无描述" : record.note)
                    .foregroundStyle(record.note.isEmpty ? .tertiary : .secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                editorRequest = .edit(record)
            } label: {
                Image(systemName: "pencil")
            }
            .help("编辑")
            Button(role: .destructive) {
                pendingDeletion = record
            } label: {
                Image(systemName: "trash")
            }
            .help("删除")
        }
        .padding(.vertical, 10)
    }

    private var todayStatusText: String {
        let count = store.bowelMovementCount(on: .now)
        return count == 0 ? "今天还没有记录" : "今天已经记录 \(count) 次"
    }

    private var statusTitle: String {
        switch selectedStatus {
        case let .recorded(count): "当天记录 \(count) 次"
        case .noMovement: "没拉"
        case .pending: "今天还没记录"
        case .future: "未来日期"
        }
    }

    private var statusEmoji: String {
        switch selectedStatus {
        case .recorded: "💩"
        case .noMovement: "—"
        case .pending: "⏳"
        case .future: "○"
        }
    }

    private var statusColor: Color {
        switch selectedStatus {
        case .recorded: .brown
        case .noMovement: .red
        case .pending: .orange
        case .future: .secondary
        }
    }

    private var emptyTitle: String {
        selectedStatus == .noMovement ? "没拉" : "没有粑粑记录"
    }

    private var emptyIcon: String {
        selectedStatus == .noMovement ? "xmark.circle" : "tray"
    }

    private var emptyDescription: String {
        selectedStatus == .future
            ? "未来日期不能补录。"
            : "可以点击“补录一次”添加记录。"
    }

    private func moveSelectedDate(by value: Int) {
        selectedDate = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: value,
            to: selectedDate
        ) ?? selectedDate
    }
}

private struct BowelMovementEditorRequest: Identifiable {
    let id = UUID()
    let recordID: UUID?
    let occurredAt: Date
    let note: String

    static func new(on date: Date) -> BowelMovementEditorRequest {
        let calendar = Calendar.autoupdatingCurrent
        let occurredAt = calendar.isDateInToday(date)
            ? Date.now
            : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        return BowelMovementEditorRequest(
            recordID: nil,
            occurredAt: occurredAt,
            note: ""
        )
    }

    static func edit(_ record: BowelMovementRecord) -> BowelMovementEditorRequest {
        BowelMovementEditorRequest(
            recordID: record.id,
            occurredAt: record.occurredAt,
            note: record.note
        )
    }
}

private struct BowelMovementEditorSheet: View {
    @EnvironmentObject private var store: AttendanceStore
    @Environment(\.dismiss) private var dismiss

    let request: BowelMovementEditorRequest
    @State private var occurredAt: Date
    @State private var note: String

    init(request: BowelMovementEditorRequest) {
        self.request = request
        _occurredAt = State(initialValue: request.occurredAt)
        _note = State(initialValue: request.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(request.recordID == nil ? "补录粑粑" : "编辑粑粑记录")
                    .font(.title2.bold())
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            DatePicker(
                "日期与时间",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("描述（可选）")
                    .font(.headline)
                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(
                        .quaternary.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                Text("\(note.count) / 500")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(note.count > 500 ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                Button("保存") {
                    if store.saveBowelMovement(
                        id: request.recordID,
                        occurredAt: occurredAt,
                        note: note
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.count > 500 || occurredAt > .now)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
