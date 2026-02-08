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

    /// Color escalation based on total daily YouTube time (videos + shorts)
    private var ytColor: Color {
        switch monitor.totalYoutubeSeconds {
        case ..<1800: return .green
        case ..<3600: return .yellow
        case ..<5400: return .orange
        default: return .red
        }
    }

    /// Budget color
    private var budgetColor: Color {
        let remaining = monitor.budgetRemainingSeconds
        if remaining < 0 { return .red }
        if remaining < 300 { return .orange } // < 5 min left
        return .green
    }

    /// Budget label text
    private var budgetLabel: String {
        let remaining = monitor.budgetRemainingSeconds
        if remaining >= 0 {
            return "\(remaining / 60)m left"
        } else {
            return "\(abs(remaining) / 60)m over"
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, store: store)
        } label: {
            HStack(spacing: 6) {
                if monitor.currentCategory.isYouTube {
                    Image(systemName: "play.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                } else {
                    Image(systemName: "clock.fill")
                }

                // YouTube total with escalation color
                if monitor.totalYoutubeSeconds > 0 {
                    Text(TimeFormatter.format(seconds: monitor.totalYoutubeSeconds))
                        .foregroundStyle(ytColor)
                }

                // Budget remaining with its own color
                if monitor.totalYoutubeSeconds > 0 || monitor.workingSeconds > 0 {
                    Text(budgetLabel)
                        .foregroundStyle(budgetColor)
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
            }

            let summary = store.todaySummary()
            monitor.youtubeSeconds = summary[.youtube] ?? 0
            monitor.youtubeShortsSeconds = summary[.youtubeShorts] ?? 0
            monitor.workingSeconds = summary[.working] ?? 0

            if UserDefaults.standard.object(forKey: "startOnLaunch") == nil || UserDefaults.standard.bool(forKey: "startOnLaunch") {
                monitor.start()
                logger.info("Monitor wired and started")
            }
        }
        appDelegate.monitor = monitor
    }
}
