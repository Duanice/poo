import SwiftData
import SwiftUI

@main
struct DakaApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: AttendanceStore

    init() {
        do {
            let container = try AppDataContainer.make()
            modelContainer = container
            _store = StateObject(wrappedValue: AttendanceStore(modelContainer: container))
        } catch {
            fatalError("无法创建打卡数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .modelContainer(modelContainer)
                .frame(minWidth: 940, minHeight: 650)
                .onOpenURL { url in
                    store.handleDeepLink(url)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1080, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("刷新打卡数据") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarAttendanceView()
                .environmentObject(store)
        } label: {
            Label(
                "\(AttendanceCalculator.compactDuration(store.currentTotalMinutes)) / \(AttendanceCalculator.compactDuration(AppSettingsSnapshot.load().targetMinutes))",
                systemImage: "clock.badge.checkmark"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 520, height: 500)
        }
    }
}
