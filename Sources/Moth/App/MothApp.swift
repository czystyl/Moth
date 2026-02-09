import SwiftUI
import os

private let logger = Logger(subsystem: "com.moth", category: "App")

@main
struct MothApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ActivityMonitor()
    private let store = ActivityStore()

    init() {
        do {
            try Database.shared.open()
        } catch {
            logger.error("Failed to open database: \(error.localizedDescription, privacy: .public)")
        }
        store.createTables()
        store.rollupOldSamples()
    }

    /// Budget color based on 7-day rolling budget
    private var budgetColor: Color {
        let remaining = monitor.budgetRemainingSeconds
        if remaining < 0 { return .red }
        if remaining < 300 { return .orange } // < 5 min left
        return .green
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, store: store)
        } label: {
            HStack(spacing: 6) {
                if !monitor.isRunning {
                    Image(nsImage: MothIcon.resting)
                    Text("⏸ Paused")
                } else if monitor.currentCategory.isYouTube {
                    Image(nsImage: MothIcon.active(
                        color: monitor.budgetRemainingSeconds < 0 ? .systemRed : .systemYellow
                    ))
                    Text("▶ \(TimeFormatter.format(seconds: monitor.youtubeSessionSeconds)) · \(TimeFormatter.format(seconds: monitor.totalYoutubeSeconds)) today")
                        .foregroundStyle(budgetColor)
                } else {
                    Image(nsImage: MothIcon.resting)
                }
            }
            .task {
                wireUpIfNeeded()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func wireUpIfNeeded() {
        if monitor.onSummaryUpdate == nil {
            monitor.onSummaryUpdate = { [store] category, seconds in
                store.updateDailySummary(category: category, seconds: seconds)
            }
            monitor.onInsertSample = { [store] category, appName, windowTitle in
                store.insertSample(category: category, appName: appName, windowTitle: windowTitle)
                if category.isYouTube {
                    store.recordWatch(category: category, title: windowTitle)
                }
            }
            monitor.onDayChanged = { [store, weak monitor] in
                store.rollupOldSamples()
                let summary = store.todaySummary()
                monitor?.youtubeSeconds = summary[.youtube] ?? 0
                monitor?.youtubeShortsSeconds = summary[.youtubeShorts] ?? 0
                monitor?.workingSeconds = summary[.working] ?? 0
                let history = store.past6DaysBudgetData()
                monitor?.past6DaysYoutubeSeconds = history.youtubeSeconds
                monitor?.past6DaysWorkingSeconds = history.workingSeconds
            }

            let summary = store.todaySummary()
            monitor.youtubeSeconds = summary[.youtube] ?? 0
            monitor.youtubeShortsSeconds = summary[.youtubeShorts] ?? 0
            monitor.workingSeconds = summary[.working] ?? 0

            let history = store.past6DaysBudgetData()
            monitor.past6DaysYoutubeSeconds = history.youtubeSeconds
            monitor.past6DaysWorkingSeconds = history.workingSeconds

            if UserDefaults.standard.object(forKey: "startOnLaunch") == nil || UserDefaults.standard.bool(forKey: "startOnLaunch") {
                monitor.start()
                logger.info("Monitor wired and started")
            }
        }
        appDelegate.monitor = monitor
    }
}
