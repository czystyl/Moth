import Foundation

struct TimeFormatter {
    static func format(seconds: Int) -> String {
        let clamped = max(0, seconds)
        if clamped < 60 {
            return "\(clamped)s"
        }
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
