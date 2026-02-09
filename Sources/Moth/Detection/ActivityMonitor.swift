import Foundation
import AppKit
import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "com.moth", category: "ActivityMonitor")

@MainActor
final class ActivityMonitor: ObservableObject {
    @Published var currentCategory: ActivityCategory = .idle
    @Published var currentAppName: String = ""
    @Published var currentWindowTitle: String = ""
    @Published private(set) var isRunning: Bool = false
    @Published var youtubeSeconds: Int = 0
    @Published var youtubeShortsSeconds: Int = 0
    @Published var workingSeconds: Int = 0

    // Past 6 days (from DB, refreshed on startup + day change)
    var past6DaysYoutubeSeconds: Int = 0
    var past6DaysWorkingSeconds: Int = 0

    private var timer: Timer?

    /// Called every 2s — always update daily summary
    var onSummaryUpdate: ((ActivityCategory, Int) -> Void)?
    /// Called only on category change or heartbeat — insert a sample row
    var onInsertSample: ((ActivityCategory, String, String) -> Void)?

    /// Set by AppDelegate when screen locks/unlocks
    var screenLocked: Bool = false

    private var lastCategory: ActivityCategory?
    private var lastSampleTime: Date = .distantPast
    private var lastPollDay: String = ""

    /// Called when the calendar day changes (e.g., after overnight sleep).
    /// The host should reload today's summary from the store.
    var onDayChanged: (() -> Void)?

    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("reminderIntervalMinutes") var reminderIntervalMinutes = 5

    // YouTube session tracking for break reminders
    private var youtubeSessionStart: Date?
    private var lastBreakReminder: Date = .distantPast

    private static let idleThreshold: Double = 120 // seconds
    private static let heartbeatInterval: TimeInterval = 60 // seconds

    private func effectiveInterval(sessionMinutes: Int) -> TimeInterval {
        return TimeInterval(reminderIntervalMinutes * 60)
    }

    // YouTube budget: minutes of YouTube earned per hour of work
    @AppStorage("ytBudgetMinutesPerHour") var ytBudgetMinutesPerHour: Double = 10

    /// Total YouTube time today (videos + shorts combined)
    var totalYoutubeSeconds: Int {
        youtubeSeconds + youtubeShortsSeconds
    }

    /// 7-day rolling YouTube total (past 6 days + today)
    var weekYoutubeSeconds: Int {
        past6DaysYoutubeSeconds + totalYoutubeSeconds
    }

    /// 7-day rolling work total (past 6 days + today)
    var weekWorkingSeconds: Int {
        past6DaysWorkingSeconds + workingSeconds
    }

    /// Earned YouTube seconds based on 7-day rolling work time
    var earnedYoutubeSeconds: Int {
        Int((Double(weekWorkingSeconds) / 3600.0) * ytBudgetMinutesPerHour * 60.0)
    }

    /// Remaining budget (negative = over budget), 7-day rolling
    var budgetRemainingSeconds: Int {
        earnedYoutubeSeconds - weekYoutubeSeconds
    }

    /// Today's budget remaining (negative = over budget)
    var todayBudgetRemainingSeconds: Int {
        let earned = Int((Double(workingSeconds) / 3600.0) * ytBudgetMinutesPerHour * 60.0)
        return earned - totalYoutubeSeconds
    }

    /// Current continuous YouTube session duration in seconds
    var youtubeSessionSeconds: Int {
        guard let start = youtubeSessionStart else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        isRunning = true
        logger.info("Monitor started")
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        youtubeSessionStart = nil
        logger.info("Monitor stopped")
    }

    private func poll() {
        checkDayChange()
        let (category, appName, windowTitle) = detectActivity()
        currentCategory = category
        currentAppName = appName
        currentWindowTitle = windowTitle

        // Track YouTube time in-memory for menu bar label
        if category == .youtube {
            youtubeSeconds += 2
        }
        if category == .youtubeShorts {
            youtubeShortsSeconds += 2
        }

        // Session tracking + break reminders for all YouTube
        if category.isYouTube {
            trackYoutubeSession()
        } else {
            youtubeSessionStart = nil
        }

        // Track working time in-memory for budget
        if category == .working {
            workingSeconds += 2
        }

        // Always update daily summary (every 2s tick = 2s of time)
        onSummaryUpdate?(category, 2)

        // Insert sample only on category change or heartbeat
        let now = Date()
        let categoryChanged = category != lastCategory
        let heartbeatDue = now.timeIntervalSince(lastSampleTime) >= Self.heartbeatInterval

        if categoryChanged || heartbeatDue {
            onInsertSample?(category, appName, windowTitle)
            lastSampleTime = now
            lastCategory = category
        }
    }

    private func trackYoutubeSession() {
        guard notificationsEnabled else {
            youtubeSessionStart = nil
            lastBreakReminder = .distantPast
            return
        }

        let now = Date()

        if youtubeSessionStart == nil {
            youtubeSessionStart = now
            lastBreakReminder = now
        }

        guard let sessionStart = youtubeSessionStart else { return }
        let sessionMinutes = Int(now.timeIntervalSince(sessionStart) / 60)
        let timeSinceLastReminder = now.timeIntervalSince(lastBreakReminder)

        // Over budget: use configured interval
        let minInterval = TimeInterval(reminderIntervalMinutes * 60)
        if budgetRemainingSeconds < 0 && timeSinceLastReminder >= minInterval {
            fireBreakReminder(minutes: sessionMinutes)
            lastBreakReminder = now
            return
        }

        // Escalating interval based on session length
        let interval = effectiveInterval(sessionMinutes: sessionMinutes)
        let sessionDuration = now.timeIntervalSince(sessionStart)

        if sessionDuration >= interval && timeSinceLastReminder >= interval {
            fireBreakReminder(minutes: sessionMinutes)
            lastBreakReminder = now
        }
    }

    func fireBreakReminder(minutes: Int) {
        let overBudget = budgetRemainingSeconds < 0

        // Escalating severity
        let severity: BreakReminderPanel.Severity
        let body: String
        if overBudget {
            let overMinutes = abs(budgetRemainingSeconds) / 60
            severity = .critical
            body = "\(overMinutes)m over budget. Stop now."
        } else if minutes >= 30 {
            severity = .critical
            body = "Still watching after \(minutes) minutes. Close it."
        } else if minutes >= 15 {
            severity = .warning
            body = "\(minutes) minutes on YouTube. Time to stop."
        } else {
            severity = .gentle
            body = "You've been watching for \(minutes) minutes. Take a break?"
        }

        BreakReminderPanel.show(
            severity: severity,
            body: body,
            videoSeconds: youtubeSeconds,
            shortsSeconds: youtubeShortsSeconds,
            budgetRemainingSeconds: budgetRemainingSeconds,
            earnedSeconds: earnedYoutubeSeconds
        )

        NSSound(named: "Funk")?.play()
        NSApp.requestUserAttention(.criticalRequest)

        logger.info("Break reminder fired (\(severity)): \(body)")
    }

    private func checkDayChange() {
        let today = Self.todayString()
        if today != lastPollDay {
            if !lastPollDay.isEmpty {
                logger.info("Day changed from \(self.lastPollDay) to \(today), resetting counters")
                youtubeSeconds = 0
                youtubeShortsSeconds = 0
                workingSeconds = 0
                youtubeSessionStart = nil
                lastBreakReminder = .distantPast
                lastCategory = nil
                lastSampleTime = .distantPast
                onDayChanged?()
            }
            lastPollDay = today
        }
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }

    private func detectActivity() -> (ActivityCategory, String, String) {
        // Screen locked → immediate idle
        if screenLocked {
            return (.idle, "", "")
        }

        // 1. Check YouTube first — watching is passive, user may be idle at keyboard
        let arcResult = ArcBrowserDetector.detect()
        if arcResult.isPlaying {
            let title = arcResult.title.isEmpty ? "youtube.com" : arcResult.title
            let category: ActivityCategory = arcResult.isShort ? .youtubeShorts : .youtube
            return (category, "Arc", title)
        }

        // 2. Check idle (only if not watching YouTube)
        let idleTime = IdleDetector.idleTimeSeconds()
        if idleTime >= Self.idleThreshold {
            return (.idle, "", "")
        }

        // 3. Working
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? ""
        return (.working, appName, "")
    }
}
