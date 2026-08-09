import Combine
import Foundation
import SwiftData
import WidgetKit

enum FeedbackStyle {
    case success
    case information
    case warning
    case failure
}

struct AppFeedback: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    let style: FeedbackStyle
    let actionTitle: String?
}

struct RecordEditRequest: Identifiable {
    let id = UUID()
    let date: Date
}

private struct UndoRecordSnapshot {
    let date: Date
    let record: BackupRecord?
}

@MainActor
final class AttendanceStore: ObservableObject {
    @Published private(set) var records: [AttendanceRecord] = []
    @Published private(set) var bowelMovements: [BowelMovementRecord] = []
    @Published private(set) var changeToken = UUID()
    @Published var errorMessage: String?
    @Published var feedback: AppFeedback?
    @Published var editRequest: RecordEditRequest?
    @Published var requestedDestination: SidebarDestination?

    let modelContext: ModelContext
    private let calendar: Calendar
    private var pendingUndo: UndoRecordSnapshot?
    private var feedbackTask: Task<Void, Never>?

    init(modelContainer: ModelContainer, calendar: Calendar = .autoupdatingCurrent) {
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
        self.calendar = calendar
        do {
            try restoreFromWidgetSnapshotIfNeeded()
        } catch {
            errorMessage = "旧版数据恢复失败：\(error.localizedDescription)"
            return
        }
        refresh()
    }

    var currentPeriod: AttendancePeriod {
        AttendancePeriodCalculator.period(containing: .now, calendar: calendar)
    }

    var currentPeriodRecords: [AttendanceRecord] {
        records(in: currentPeriod)
    }

    var currentTotalMinutes: Int {
        currentCatchUpPlan.completedMinutes
    }

    var currentCatchUpPlan: CatchUpPlan {
        CatchUpPlanCalculator.plan(
            period: currentPeriod,
            summaries: currentDailySummaries,
            targetMinutes: AppSettingsSnapshot.load().targetMinutes,
            calendar: calendar
        )
    }

    var currentDailySummaries: [DailyAttendanceSummary] {
        AttendanceSummaryBuilder.make(
            period: currentPeriod,
            records: records,
            calendar: calendar
        )
    }

    var todayRecord: AttendanceRecord? {
        record(on: .now)
    }

    func records(in period: AttendancePeriod) -> [AttendanceRecord] {
        records.filter { period.contains($0.workDate) }
    }

    func record(on date: Date) -> AttendanceRecord? {
        records.first { calendar.isDate($0.workDate, inSameDayAs: date) }
    }

    func bowelMovements(on date: Date) -> [BowelMovementRecord] {
        bowelMovements.filter {
            calendar.isDate($0.occurredAt, inSameDayAs: date)
        }
    }

    func bowelMovementCount(on date: Date) -> Int {
        bowelMovements(on: date).count
    }

    func bowelDayStatus(on date: Date, now: Date = .now) -> BowelDayStatus {
        BowelDayStatusResolver.status(
            on: date,
            records: bowelMovements,
            now: now,
            calendar: calendar
        )
    }

    func refresh() {
        do {
            var descriptor = FetchDescriptor<AttendanceRecord>()
            descriptor.sortBy = [SortDescriptor(\.workDate, order: .reverse)]
            records = try modelContext.fetch(descriptor)
            var bowelDescriptor = FetchDescriptor<BowelMovementRecord>()
            bowelDescriptor.sortBy = [SortDescriptor(\.occurredAt, order: .reverse)]
            bowelMovements = try modelContext.fetch(bowelDescriptor)
            changeToken = UUID()
        } catch {
            errorMessage = "读取本地记录失败：\(error.localizedDescription)"
            return
        }

        do {
            try WidgetSnapshotStore.write(
                records: records,
                settings: AppSettingsSnapshot.load()
            )
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        } catch {
            errorMessage = "桌面组件数据同步失败：\(error.localizedDescription)"
        }
    }

    func save(
        workDate: Date,
        checkIn: Date?,
        checkOut: Date?,
        note: String
    ) -> Bool {
        do {
            let service = AttendanceMutationService(context: modelContext, calendar: calendar)
            let saved = try service.save(
                workDate: workDate,
                checkIn: checkIn,
                checkOut: checkOut,
                note: note
            )
            didMutate()
            presentFeedback(
                title: "\(DakaFormatters.shortDay(workDate)) 记录已保存",
                detail: "当日 \(AttendanceCalculator.formatDuration(saved.durationMinutes))",
                style: .success
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveBowelMovement(
        id: UUID? = nil,
        occurredAt: Date,
        note: String
    ) -> Bool {
        do {
            let item = try BowelMovementMutationService(
                context: modelContext
            ).save(
                id: id,
                occurredAt: occurredAt,
                note: note
            )
            refresh()
            presentFeedback(
                title: id == nil ? "粑粑记录已添加 💩" : "粑粑记录已更新",
                detail: DakaFormatters.day(item.occurredAt),
                style: .success
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteBowelMovement(id: UUID) -> Bool {
        do {
            try BowelMovementMutationService(
                context: modelContext
            ).delete(id: id)
            refresh()
            presentFeedback(
                title: "粑粑记录已删除",
                style: .warning
            )
            return true
        } catch {
            errorMessage = "删除粑粑记录失败：\(error.localizedDescription)"
            return false
        }
    }

    func checkInNow() {
        do {
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).checkInNow()
            didMutate()
            presentFeedback(
                title: "上班时间已记录",
                detail: DakaFormatters.time(record(on: .now)?.checkIn),
                style: .success
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkOutNow() {
        do {
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).checkOutNow()
            didMutate()
            let today = record(on: .now)
            presentFeedback(
                title: "下班时间已记录",
                detail: "今日 \(AttendanceCalculator.formatDuration(today?.durationMinutes ?? 0))",
                style: .success
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func delete(on date: Date) -> Bool {
        do {
            let snapshot = record(on: date).map(BackupRecord.init)
            pendingUndo = UndoRecordSnapshot(date: date, record: snapshot)
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).delete(on: date)
            didMutate()
            presentFeedback(
                title: "\(DakaFormatters.shortDay(date)) 记录已删除",
                style: .warning,
                actionTitle: "撤销",
                duration: 6
            )
            return true
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
            return false
        }
    }

    func requiresClearingBeforeSlacking(on date: Date) -> Bool {
        guard let item = record(on: date), !item.isSlacking else {
            return false
        }
        return item.hasAnyEffectiveTime
    }

    @discardableResult
    func setSlacking(
        on date: Date,
        enabled: Bool,
        clearExistingRecord: Bool = false
    ) -> Bool {
        do {
            pendingUndo = UndoRecordSnapshot(
                date: date,
                record: record(on: date).map(BackupRecord.init)
            )
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).setSlacking(
                on: date,
                enabled: enabled,
                clearExistingRecord: clearExistingRecord
            )
            didMutate()
            let plan = currentCatchUpPlan
            let detail: String
            if plan.isCompleted {
                detail = "本周期目标已完成"
            } else if plan.isImpossible {
                detail = "本周期已无剩余可打卡日期"
            } else {
                detail = "剩余 \(plan.eligibleDays) 天，每天需要 \(AttendanceCalculator.formatDuration(plan.requiredMinutesPerDay))"
            }
            presentFeedback(
                title: enabled
                    ? "\(DakaFormatters.shortDay(date)) 已设为摆烂日"
                    : "已取消 \(DakaFormatters.shortDay(date)) 摆烂状态",
                detail: detail,
                style: enabled ? .information : .success,
                actionTitle: "撤销",
                duration: 6
            )
            return true
        } catch {
            pendingUndo = nil
            errorMessage = error.localizedDescription
            return false
        }
    }

    func undoLastChange() {
        guard let pendingUndo else { return }
        do {
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).delete(on: pendingUndo.date)
            if let snapshot = pendingUndo.record {
                modelContext.insert(
                    AttendanceRecord(
                        id: snapshot.id,
                        workDate: snapshot.workDate,
                        checkIn: snapshot.checkIn,
                        checkOut: snapshot.checkOut,
                        note: snapshot.note,
                        isSlacking: snapshot.isSlacking ?? false,
                        createdAt: snapshot.createdAt,
                        updatedAt: snapshot.updatedAt,
                        actualCheckIn: snapshot.actualCheckIn,
                        actualCheckOut: snapshot.actualCheckOut,
                        actualDurationMinutes: snapshot.actualDurationMinutes,
                        actualImportedAt: snapshot.actualImportedAt,
                        actualImportBatchID: snapshot.actualImportBatchID
                    )
                )
                try modelContext.save()
            }
            self.pendingUndo = nil
            didMutate()
            presentFeedback(title: "操作已撤销", style: .success)
        } catch {
            errorMessage = "撤销失败：\(error.localizedDescription)"
        }
    }

    func dismissFeedback() {
        feedbackTask?.cancel()
        feedback = nil
    }

    func openEditor(on date: Date) {
        editRequest = RecordEditRequest(date: calendar.startOfDay(for: date))
    }

    func handleDeepLink(_ url: URL) {
        switch url.host {
        case "today":
            openEditor(on: .now)
        case "record":
            let value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let components = value.split(separator: "-").compactMap { Int($0) }
            guard components.count == 3,
                  let date = calendar.date(
                    from: DateComponents(
                        year: components[0],
                        month: components[1],
                        day: components[2]
                    )
                  ) else {
                return
            }
            openEditor(on: date)
        case "quick":
            switch url.path {
            case "/check-in":
                checkInNow()
            case "/check-out":
                checkOutNow()
            case "/toggle-slacking":
                toggleTodaySlackingFromWidget()
            default:
                break
            }
        case "sync":
            refresh()
        case "import":
            requestedDestination = .actualImport
        case "bowel":
            requestedDestination = .bowelMovement
        default:
            break
        }
    }

    func replaceAll(with backup: BackupEnvelope) throws {
        do {
            let existing = try modelContext.fetch(FetchDescriptor<AttendanceRecord>())
            existing.forEach(modelContext.delete)
            for item in backup.records {
                modelContext.insert(
                    AttendanceRecord(
                        id: item.id,
                        workDate: item.workDate,
                        checkIn: item.checkIn,
                        checkOut: item.checkOut,
                        note: item.note,
                        isSlacking: item.isSlacking ?? false,
                        createdAt: item.createdAt,
                        updatedAt: item.updatedAt,
                        actualCheckIn: item.actualCheckIn,
                        actualCheckOut: item.actualCheckOut,
                        actualDurationMinutes: item.actualDurationMinutes,
                        actualImportedAt: item.actualImportedAt,
                        actualImportBatchID: item.actualImportBatchID
                    )
                )
            }

            if backup.formatVersion >= 4 {
                let existingBowelMovements = try modelContext.fetch(
                    FetchDescriptor<BowelMovementRecord>()
                )
                existingBowelMovements.forEach(modelContext.delete)
                for item in backup.bowelMovements ?? [] {
                    modelContext.insert(
                        BowelMovementRecord(
                            id: item.id,
                            occurredAt: item.occurredAt,
                            note: item.note,
                            createdAt: item.createdAt,
                            updatedAt: item.updatedAt
                        )
                    )
                }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        didMutate()
        presentFeedback(
            title: "备份恢复完成",
            detail: restoreFeedbackDetail(for: backup),
            style: .success
        )
    }

    func importLabAttendance(
        _ rows: [LabAttendanceImportRow]
    ) throws -> LabAttendanceImportApplyResult {
        _ = try BackupService.writeAutomaticBackup(
            records: records,
            bowelMovements: bowelMovements
        )
        let result = try LabAttendanceImportService(
            context: modelContext,
            calendar: calendar
        ).apply(rows)
        refresh()
        presentFeedback(
            title: "实验室实际数据已更新",
            detail: "更新 \(result.changed) 天，\(result.unchanged) 天无变化",
            style: .success
        )
        return result
    }

    @discardableResult
    func clearActualData(on date: Date) -> Bool {
        guard let existing = record(on: date), existing.hasActualData else {
            return true
        }
        do {
            pendingUndo = UndoRecordSnapshot(
                date: date,
                record: BackupRecord(record: existing)
            )
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).clearActualData(on: date)
            refresh()
            presentFeedback(
                title: "\(DakaFormatters.shortDay(date)) 实际数据已移除",
                detail: "统计已恢复使用手动记录",
                style: .warning,
                actionTitle: "撤销",
                duration: 6
            )
            return true
        } catch {
            pendingUndo = nil
            errorMessage = "移除实际数据失败：\(error.localizedDescription)"
            return false
        }
    }

    private func didMutate() {
        refresh()
    }

    private func restoreFeedbackDetail(for backup: BackupEnvelope) -> String {
        if backup.formatVersion >= 4 {
            return "已恢复 \(backup.records.count) 条打卡记录、"
                + "\(backup.bowelMovements?.count ?? 0) 条粑粑记录"
        }
        return "已恢复 \(backup.records.count) 条打卡记录；"
            + "旧版备份不含粑粑数据，现有粑粑记录已保留"
    }

    private func restoreFromWidgetSnapshotIfNeeded() throws {
        guard try modelContext.fetchCount(FetchDescriptor<AttendanceRecord>()) == 0 else {
            return
        }

        let snapshot: WidgetSnapshotDocument
        do {
            snapshot = try WidgetSnapshotStore.load()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return
        }
        guard !snapshot.records.isEmpty else { return }

        for item in snapshot.records {
            let containsActualData = item.isActualData == true
            modelContext.insert(
                AttendanceRecord(
                    workDate: item.workDate,
                    checkIn: containsActualData ? nil : item.checkIn,
                    checkOut: containsActualData ? nil : item.checkOut,
                    isSlacking: item.isSlacking,
                    actualCheckIn: containsActualData ? item.checkIn : nil,
                    actualCheckOut: containsActualData ? item.checkOut : nil,
                    actualDurationMinutes: containsActualData
                        ? item.durationMinutesOverride
                        : nil,
                    actualImportedAt: containsActualData ? snapshot.generatedAt : nil
                )
            )
        }
        try modelContext.save()
    }

    private func toggleTodaySlackingFromWidget() {
        if todayRecord?.isSlacking == true {
            setSlacking(on: .now, enabled: false)
            return
        }
        if requiresClearingBeforeSlacking(on: .now) {
            openEditor(on: .now)
            presentFeedback(
                title: "今天已有打卡记录",
                detail: "请在编辑页确认清空记录后再设为摆烂日",
                style: .warning
            )
            return
        }
        setSlacking(on: .now, enabled: true)
    }

    private func presentFeedback(
        title: String,
        detail: String? = nil,
        style: FeedbackStyle,
        actionTitle: String? = nil,
        duration: Double = 2.5
    ) {
        feedbackTask?.cancel()
        feedback = AppFeedback(
            title: title,
            detail: detail,
            style: style,
            actionTitle: actionTitle
        )
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.feedback = nil
        }
    }
}
