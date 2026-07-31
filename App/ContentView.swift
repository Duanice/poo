import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case overview = "概览"
    case history = "历史记录"
    case backup = "备份与导出"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .history: "calendar"
        case .backup: "externaldrive.badge.timemachine"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AttendanceStore
    @State private var selection: SidebarDestination? = .overview

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationSplitView {
                List(SidebarDestination.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
                .navigationTitle("打卡")
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            } detail: {
                Group {
                    switch selection ?? .overview {
                    case .overview:
                        DashboardView()
                    case .history:
                        HistoryView()
                    case .backup:
                        BackupView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            if let feedback = store.feedback {
                FeedbackBanner(feedback: feedback)
                    .environmentObject(store)
                    .padding(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: store.feedback?.id)
        .sheet(item: $store.editRequest) { request in
            RecordEditorSheet(date: request.date)
                .environmentObject(store)
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "发生未知错误")
        }
    }
}
