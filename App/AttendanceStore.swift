import Combine
import Foundation
import SwiftData
import WidgetKit

@MainActor
final class AttendanceStore: ObservableObject {
    @Published private(set) var records: [AttendanceRecord] = []
    @Published private(set) var changeToken = UUID()
    @Published var errorMessage: String?

    let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContainer: ModelContainer, calendar: Calendar = .autoupdatingCurrent) {
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
        self.calendar = calendar
        refresh()
    }

    var currentPeriod: AttendancePeriod {
        AttendancePeriodCalculator.period(containing: .now, calendar: calendar)
    }

    var currentPeriodRecords: [AttendanceRecord] {
        records(in: currentPeriod)
    }

    var currentTotalMinutes: Int {
        let now = Date.now
        return currentPeriodRecords
            .filter { $0.workDate <= now }
            .reduce(0) { $0 + $1.durationMinutes }
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

    func refresh() {
        do {
            var descriptor = FetchDescriptor<AttendanceRecord>()
            descriptor.sortBy = [SortDescriptor(\.workDate, order: .reverse)]
            records = try modelContext.fetch(descriptor)
            changeToken = UUID()
        } catch {
            errorMessage = "读取打卡记录失败：\(error.localizedDescription)"
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
            try service.save(
                workDate: workDate,
                checkIn: checkIn,
                checkOut: checkOut,
                note: note
            )
            didMutate()
            return true
        } catch {
            errorMessage = error.localizedDescription
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(on date: Date) {
        do {
            try AttendanceMutationService(
                context: modelContext,
                calendar: calendar
            ).delete(on: date)
            didMutate()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func replaceAll(with items: [BackupRecord]) throws {
        let existing = try modelContext.fetch(FetchDescriptor<AttendanceRecord>())
        existing.forEach(modelContext.delete)
        for item in items {
            modelContext.insert(
                AttendanceRecord(
                    id: item.id,
                    workDate: item.workDate,
                    checkIn: item.checkIn,
                    checkOut: item.checkOut,
                    note: item.note,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            )
        }
        try modelContext.save()
        didMutate()
    }

    private func didMutate() {
        refresh()
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
    }
}
