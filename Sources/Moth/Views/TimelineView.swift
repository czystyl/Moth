import SwiftUI

struct TimelineView: View {
    let timeline: [ActivityCategory: [TimeRange]]

    // 5am to 11pm = 18 hours
    private static let startHour = 5
    private static let endHour = 23
    private static let totalHours = endHour - startHour // 18

    private let hourLabels = [5, 9, 13, 17, 21, 23]

    private var dayAnchor: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var axisStart: Int {
        Int(dayAnchor.timeIntervalSince1970) + Self.startHour * 3600
    }

    private var axisEnd: Int {
        Int(dayAnchor.timeIntervalSince1970) + Self.endHour * 3600
    }

    private var axisDuration: Int {
        axisEnd - axisStart
    }

    // Categories to show (only those with data, in canonical order)
    private var categories: [ActivityCategory] {
        ActivityCategory.allCases.filter { timeline[$0] != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category rows
            ForEach(categories) { category in
                HStack(spacing: 8) {
                    Text(category.label)
                        .font(.system(.caption, design: .rounded))
                        .frame(width: 70, alignment: .trailing)

                    GeometryReader { geo in
                        let width = geo.size.width
                        ForEach(Array(clippedRanges(for: category).enumerated()), id: \.offset) { _, range in
                            let x = xPosition(for: range.start, in: width)
                            let w = max(2, xPosition(for: range.end, in: width) - x)
                            Rectangle()
                                .fill(category.color)
                                .frame(width: w, height: 14)
                                .position(x: x + w / 2, y: 9)
                        }
                    }
                    .frame(height: 18)
                }
                .padding(.vertical, 1)
            }

            // Time axis
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 70)

                GeometryReader { geo in
                    let width = geo.size.width
                    ForEach(hourLabels, id: \.self) { hour in
                        let ts = Int(dayAnchor.timeIntervalSince1970) + hour * 3600
                        let x = xPosition(for: ts, in: width)
                        Text(formatHour(hour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .position(x: x, y: 8)
                    }
                }
                .frame(height: 16)
            }
        }
    }

    private func clippedRanges(for category: ActivityCategory) -> [TimeRange] {
        guard let ranges = timeline[category] else { return [] }
        return ranges.compactMap { range in
            let s = max(range.start, axisStart)
            let e = min(range.end, axisEnd)
            guard s < e else { return nil }
            return TimeRange(start: s, end: e)
        }
    }

    private func xPosition(for timestamp: Int, in width: CGFloat) -> CGFloat {
        let fraction = CGFloat(timestamp - axisStart) / CGFloat(axisDuration)
        return fraction * width
    }

    private func formatHour(_ hour: Int) -> String {
        let h12 = hour % 12
        let display = h12 == 0 ? 12 : h12
        let suffix = hour < 12 ? "a" : "p"
        return "\(display)\(suffix)"
    }
}
