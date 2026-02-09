import SwiftUI

struct MenuBarView: View {
    @ObservedObject var monitor: ActivityMonitor
    let store: ActivityStore
    @State private var summary: [ActivityCategory: Int] = [:]
    @State private var timeline: [ActivityCategory: [TimeRange]] = [:]
    @State private var weekTrend: [(String, Int)] = []
    @State private var settingsExpanded = false
    @AppStorage("startOnLaunch") private var startOnLaunch = true
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    /// Use live monitor values for active categories, DB for idle
    private func liveSeconds(for category: ActivityCategory) -> Int {
        switch category {
        case .youtube: return monitor.youtubeSeconds
        case .youtubeShorts: return monitor.youtubeShortsSeconds
        case .working: return monitor.workingSeconds
        case .idle: return summary[.idle] ?? 0
        }
    }

    private var totalActiveSeconds: Int {
        monitor.youtubeSeconds + monitor.youtubeShortsSeconds + monitor.workingSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text(TimeFormatter.format(seconds: totalActiveSeconds))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            ForEach(ActivityCategory.allCases) { category in
                StatsRow(
                    category: category,
                    seconds: liveSeconds(for: category),
                    isActive: monitor.currentCategory == category
                )
            }

            // Budget row
            BudgetRow(monitor: monitor)

            Divider()

            TimelineView(timeline: timeline)

            Divider()

            WeeklyTrendView(data: weekTrend.map { (date: $0.0, seconds: $0.1) })

            Divider()

            Button {
                settingsExpanded.toggle()
            } label: {
                HStack {
                    Text("Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(settingsExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.subheadline)

            if settingsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Pause reminders", isOn: Binding(
                        get: { !monitor.notificationsEnabled },
                        set: { monitor.notificationsEnabled = !$0 }
                    ))

                    Toggle("Start on launch", isOn: $startOnLaunch)

                    Stepper(
                        "Earn \(Int(monitor.ytBudgetMinutesPerHour)) min / hour worked",
                        value: $monitor.ytBudgetMinutesPerHour,
                        in: 1...30
                    )

                    if monitor.notificationsEnabled {
                        Stepper(
                            "Remind every \(monitor.reminderIntervalMinutes) min when watching",
                            value: $monitor.reminderIntervalMinutes,
                            in: 1...30
                        )
                    }
                }
                .font(.subheadline)
                .padding(.leading, 4)
            }

            Divider()

            HStack {
                Button {
                    if monitor.isRunning {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(monitor.isRunning ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(monitor.isRunning ? "Running" : "Paused")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .foregroundStyle(.red)
            }
            .font(.subheadline)
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            refreshData()
        }
        .onReceive(refreshTimer) { _ in
            refreshData()
        }
    }

    private func refreshData() {
        summary = store.todaySummary()
        timeline = store.todayTimeline()
        weekTrend = store.weekYouTubeSummary()
    }

}

private struct BudgetRow: View {
    @ObservedObject var monitor: ActivityMonitor

    private var budgetColor: Color {
        let remaining = monitor.budgetRemainingSeconds
        if remaining < 0 { return .red }
        if remaining < 300 { return .orange }
        return .green
    }

    var body: some View {
        let remaining = monitor.budgetRemainingSeconds

        HStack {
            Image(systemName: "gauge.with.needle")
                .foregroundStyle(.secondary)
            Text("\(TimeFormatter.format(seconds: monitor.weekYoutubeSeconds)) / \(TimeFormatter.format(seconds: monitor.earnedYoutubeSeconds)) this week")
                .foregroundStyle(budgetColor)
            Spacer()
            if remaining >= 0 {
                Text("\(remaining / 60)m remaining")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("\(abs(remaining) / 60)m over")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline)
    }
}
