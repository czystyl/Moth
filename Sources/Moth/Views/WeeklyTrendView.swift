import SwiftUI

struct WeeklyTrendView: View {
    let data: [(date: String, seconds: Int)]

    private var maxSeconds: Int {
        data.map(\.seconds).max() ?? 1
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }

    private var totalSeconds: Int {
        data.map(\.seconds).reduce(0, +)
    }

    private func dayLabel(for dateString: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        guard let date = fmt.date(from: dateString) else { return "?" }
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "E"
        dayFmt.timeZone = .current
        return String(dayFmt.string(from: date).prefix(1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("YouTube This Week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormatter.format(seconds: totalSeconds))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, entry in
                    let isToday = entry.date == todayString
                    let barHeight = maxSeconds > 0
                        ? max(2, CGFloat(entry.seconds) / CGFloat(maxSeconds) * 40)
                        : 2.0

                    VStack(spacing: 2) {
                        if entry.seconds > 0 {
                            Text(shortTime(entry.seconds))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        RoundedRectangle(cornerRadius: 2)
                            .fill(isToday ? Color.red : Color.red.opacity(0.4))
                            .frame(height: barHeight)

                        Text(dayLabel(for: entry.date))
                            .font(.system(size: 9))
                            .foregroundStyle(isToday ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60)
        }
    }

    private func shortTime(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let hours = m / 60
        let mins = m % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h\(mins)m"
    }
}
