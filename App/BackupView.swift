import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var store: AttendanceStore

    @State private var exportDocument = DakaExportDocument()
    @State private var exportType: UTType = .json
    @State private var exportFilename = "daka-backup"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: BackupEnvelope?
    @State private var showingRestoreConfirmation = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("备份与导出")
                        .font(.largeTitle.bold())
                    Text("保护本地数据，并按需导出到 Excel。")
                        .foregroundStyle(.secondary)
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("完整备份", systemImage: "externaldrive.badge.plus")
                            .font(.headline)
                        Text("JSON 备份包含手动记录、实验室实际数据、备注和记录元数据，可用于完整恢复。")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("导出 JSON 备份") {
                                exportJSON()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("从 JSON 恢复") {
                                showingImporter = true
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("表格导出", systemImage: "tablecells")
                            .font(.headline)
                        Text("CSV 使用 UTF-8 编码，可直接用 Microsoft Excel、Numbers 或其他表格软件打开。")
                            .foregroundStyle(.secondary)
                        Button("导出 CSV") {
                            exportCSV()
                        }
                    }
                }

                Card {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("隐私说明")
                                .font(.headline)
                            Text("所有打卡数据默认仅保存在你的 Mac。本应用没有账号系统、广告、统计代码或网络上传功能。")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                statusMessage = "导出完成"
            case .failure(let error):
                store.errorMessage = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .confirmationDialog(
            "恢复备份将替换现有全部记录",
            isPresented: $showingRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("备份当前数据并恢复", role: .destructive) {
                restorePendingBackup()
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text("恢复前会在应用数据目录中自动保存一份当前数据。")
        }
    }

    private func exportJSON() {
        do {
            exportDocument = DakaExportDocument(
                data: try BackupService.jsonData(records: store.records)
            )
            exportType = .json
            exportFilename = "daka-backup-\(DakaFormatters.exportTimestamp())"
            showingExporter = true
        } catch {
            store.errorMessage = "生成备份失败：\(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        exportDocument = DakaExportDocument(
            data: BackupService.csvData(records: store.records)
        )
        exportType = .commaSeparatedText
        exportFilename = "daka-records-\(DakaFormatters.exportTimestamp())"
        showingExporter = true
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            pendingImport = try BackupService.decode(Data(contentsOf: url))
            showingRestoreConfirmation = true
        } catch {
            store.errorMessage = "无法读取备份：\(error.localizedDescription)"
        }
    }

    private func restorePendingBackup() {
        guard let pendingImport else { return }
        do {
            _ = try BackupService.writeAutomaticBackup(records: store.records)
            try store.replaceAll(with: pendingImport.records)
            statusMessage = "已恢复 \(pendingImport.records.count) 条记录"
            self.pendingImport = nil
        } catch {
            store.errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
}
