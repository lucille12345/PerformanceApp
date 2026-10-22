import SwiftUI

@main
struct PerformanceApp: App {
    @State private var store = AppStore()
    @State private var calendar = CalendarService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(calendar)
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 920)
        #endif
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CalendarService.self) private var calendar
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "clock") }
            HistoryView().tabItem { Label("History", systemImage: "calendar") }
            StatsView().tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .background(Theme.bg)
        .onChange(of: phase) { _, p in
            guard p == .active else { return }
            store.becameActive()
            Task { await calendar.refresh() }
            refreshHealth()
        }
        .task { refreshHealth() }
    }

    private func refreshHealth() {
        #if os(iOS)
        Task { store.updateHealth(await HealthService.shared.fetchMonths()) }
        #endif
    }
}
