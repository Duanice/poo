import SwiftUI
import UniformTypeIdentifiers

struct BowelMovementView: View {
    @EnvironmentObject private var store: AttendanceStore

    @State private var editorRequest: BowelMovementEditorRequest?
    @State private var pendingDeletion: BowelMovementRecord?
    @State private var exportDocument = DakaExportDocument()
    @State private var showingExporter = false

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
                recordListCard
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

                HStack {
                    Text("默认使用当前时间，保存前可以修改日期、时间和描述。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("记录一次 💩") {
                        editorRequest = .new(on: .now)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var recordListCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("记录列表")
                            .font(.headline)
                        Text("按时间倒序排列，最新记录在前 · 共 \(store.bowelMovements.count) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("导出全部粑粑 CSV") {
                        exportDocument = DakaExportDocument(
                            data: BackupService.bowelCSVData(
                                records: store.bowelMovements
                            )
                        )
                        showingExporter = true
                    }
                    Button("补录一次") {
                        editorRequest = .new(on: .now)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                if store.bowelMovements.isEmpty {
                    ContentUnavailableView(
                        "还没有粑粑记录",
                        systemImage: "tray",
                        description: Text("点击“记录一次 💩”或“补录一次”添加。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.bowelMovements) { record in
                            bowelMovementRow(record)
                            if record.id != store.bowelMovements.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func bowelMovementRow(_ record: BowelMovementRecord) -> some View {
        HStack(spacing: 14) {
            Text("💩")
                .font(.title2)
                .accessibilityHidden(true)
            Text(DakaFormatters.deepLinkDate(record.occurredAt))
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(width: 100, alignment: .leading)
            Text(DakaFormatters.time(record.occurredAt))
                .font(.body.monospacedDigit())
                .frame(width: 52, alignment: .leading)
            Text(record.note.isEmpty ? "无描述" : record.note)
                .foregroundStyle(record.note.isEmpty ? .tertiary : .secondary)
                .lineLimit(1)
            Spacer()
            Button {
                editorRequest = .edit(record)
            } label: {
                Image(systemName: "pencil")
            }
            .help("编辑")
            .accessibilityLabel("编辑 \(DakaFormatters.deepLinkDate(record.occurredAt)) \(DakaFormatters.time(record.occurredAt)) 的记录")
            Button(role: .destructive) {
                pendingDeletion = record
            } label: {
                Image(systemName: "trash")
            }
            .help("删除")
            .accessibilityLabel("删除 \(DakaFormatters.deepLinkDate(record.occurredAt)) \(DakaFormatters.time(record.occurredAt)) 的记录")
        }
        .padding(.vertical, 10)
    }

    private var todayStatusText: String {
        let count = store.bowelMovementCount(on: .now)
        return count == 0 ? "今天还没有记录" : "今天已经记录 \(count) 次"
    }
}

struct BowelMovementEditorRequest: Identifiable {
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

struct BowelMovementEditorSheet: View {
    @EnvironmentObject private var store: AttendanceStore
    @Environment(\.dismiss) private var dismiss

    let request: BowelMovementEditorRequest
    var onSaved: ((Date) -> Void)?
    @State private var occurredAt: Date
    @State private var note: String

    init(
        request: BowelMovementEditorRequest,
        onSaved: ((Date) -> Void)? = nil
    ) {
        self.request = request
        self.onSaved = onSaved
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
                        onSaved?(occurredAt)
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

struct BowelMovementDayEditorCard: View {
    @EnvironmentObject private var store: AttendanceStore

    let date: Date
    @State private var editorRequest: BowelMovementEditorRequest?

    private var records: [BowelMovementRecord] {
        store.bowelMovements(on: date)
    }

    private var isFuture: Bool {
        Calendar.current.startOfDay(for: date)
            > Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("粑粑记录")
                            .font(.headline)
                        Text(records.isEmpty ? emptyStatus : "当天记录 \(records.count) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(records.isEmpty ? "记录一次 💩" : "再记录一次 💩") {
                        editorRequest = .new(on: date)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFuture)
                }

                ForEach(records) { record in
                    Button {
                        editorRequest = .edit(record)
                    } label: {
                        HStack(spacing: 12) {
                            Text("💩")
                            Text(DakaFormatters.time(record.occurredAt))
                                .font(.body.weight(.semibold).monospacedDigit())
                            Text(record.note.isEmpty ? "无描述" : record.note)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $editorRequest) { request in
            BowelMovementEditorSheet(request: request)
                .environmentObject(store)
        }
    }

    private var emptyStatus: String {
        if isFuture { return "未来日期不能记录" }
        if Calendar.current.isDateInToday(date) { return "今天还没记录" }
        return "没拉"
    }
}
