import Foundation
import SQLite3
import os

private let logger = Logger(subsystem: "com.moth", category: "ActivityStore")

// SQLITE_TRANSIENT tells SQLite to make its own copy of the string
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Represents a contiguous time range for a category
struct TimeRange {
    let start: Int
    let end: Int
}

final class ActivityStore {
    private let db = Database.shared

    func createTables() {
        db.exec("""
            CREATE TABLE IF NOT EXISTS activity_samples (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                category TEXT NOT NULL,
                app_name TEXT,
                window_title TEXT
            )
        """)
        db.exec("CREATE INDEX IF NOT EXISTS idx_samples_timestamp ON activity_samples(timestamp)")
        db.exec("""
            CREATE TABLE IF NOT EXISTS daily_summaries (
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                total_seconds INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (date, category)
            )
        """)
        db.exec("""
            CREATE TABLE IF NOT EXISTS watch_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                date TEXT NOT NULL,
                started_at INTEGER NOT NULL,
                ended_at INTEGER NOT NULL,
                category TEXT NOT NULL,
                title TEXT NOT NULL
            )
        """)
        db.exec("CREATE INDEX IF NOT EXISTS idx_watch_history_date ON watch_history(date)")
    }

    func insertSample(category: ActivityCategory, appName: String, windowTitle: String) {
        let now = Int(Date().timeIntervalSince1970)
        db.run(
            "INSERT INTO activity_samples (timestamp, category, app_name, window_title) VALUES (?, ?, ?, ?)"
        ) { stmt in
            sqlite3_bind_int64(stmt, 1, Int64(now))
            sqlite3_bind_text(stmt, 2, category.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, appName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, windowTitle, -1, SQLITE_TRANSIENT)
        }
    }

    func recordWatch(category: ActivityCategory, title: String) {
        let now = Int(Date().timeIntervalSince1970)
        let today = Self.todayString()

        // Check if the most recent watch_history row has the same title and ended recently
        let recent: (Int, Int, String)? = db.query(
            "SELECT id, ended_at, title FROM watch_history ORDER BY id DESC LIMIT 1",
            bind: { _ in },
            map: { stmt in
                let id = Int(sqlite3_column_int64(stmt, 0))
                let endedAt = Int(sqlite3_column_int64(stmt, 1))
                let ptr = sqlite3_column_text(stmt, 2)
                let t = ptr.map { String(cString: $0) } ?? ""
                return (id, endedAt, t)
            }
        ).first

        if let (id, endedAt, existingTitle) = recent,
           existingTitle == title,
           now - endedAt <= 120 {
            // Extend existing session
            db.run("UPDATE watch_history SET ended_at = ? WHERE id = ?") { stmt in
                sqlite3_bind_int64(stmt, 1, Int64(now))
                sqlite3_bind_int64(stmt, 2, Int64(id))
            }
            return
        }

        // Insert new watch session
        db.run("""
            INSERT INTO watch_history (date, started_at, ended_at, category, title) VALUES (?, ?, ?, ?, ?)
        """) { stmt in
            sqlite3_bind_text(stmt, 1, today, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, Int64(now))
            sqlite3_bind_int64(stmt, 3, Int64(now))
            sqlite3_bind_text(stmt, 4, category.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, title, -1, SQLITE_TRANSIENT)
        }
    }

    func updateDailySummary(category: ActivityCategory, seconds: Int) {
        let today = Self.todayString()
        db.run("""
            INSERT INTO daily_summaries (date, category, total_seconds)
            VALUES (?, ?, ?)
            ON CONFLICT(date, category) DO UPDATE SET total_seconds = total_seconds + excluded.total_seconds
        """) { stmt in
            sqlite3_bind_text(stmt, 1, today, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, category.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(seconds))
        }
    }

    func todaySummary() -> [ActivityCategory: Int] {
        let today = Self.todayString()
        let rows: [(String, Int)] = db.query(
            "SELECT category, total_seconds FROM daily_summaries WHERE date = ?",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, today, -1, SQLITE_TRANSIENT)
            },
            map: { stmt in
                let catPtr = sqlite3_column_text(stmt, 0)
                let cat = catPtr.map { String(cString: $0) } ?? ""
                let secs = Int(sqlite3_column_int(stmt, 1))
                return (cat, secs)
            }
        )
        var result: [ActivityCategory: Int] = [:]
        for (rawCat, secs) in rows {
            if let cat = ActivityCategory(rawValue: rawCat) {
                result[cat] = secs
            }
        }
        return result
    }

    /// Returns timeline data for today: contiguous time ranges per category.
    /// Samples within 120s of each other in the same category are coalesced.
    func todayTimeline() -> [ActivityCategory: [TimeRange]] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let dayStart = Int(startOfDay.timeIntervalSince1970)

        let rows: [(Int, String)] = db.query(
            "SELECT timestamp, category FROM activity_samples WHERE timestamp >= ? ORDER BY timestamp ASC",
            bind: { stmt in
                sqlite3_bind_int64(stmt, 1, Int64(dayStart))
            },
            map: { stmt in
                let ts = Int(sqlite3_column_int64(stmt, 0))
                let catPtr = sqlite3_column_text(stmt, 1)
                let cat = catPtr.map { String(cString: $0) } ?? ""
                return (ts, cat)
            }
        )

        var result: [ActivityCategory: [TimeRange]] = [:]
        var currentCat: ActivityCategory?
        var rangeStart: Int = 0
        var rangeEnd: Int = 0

        for (ts, rawCat) in rows {
            guard let cat = ActivityCategory(rawValue: rawCat) else { continue }

            if cat == currentCat && ts - rangeEnd <= 120 {
                rangeEnd = ts
            } else {
                if let prev = currentCat {
                    let range = TimeRange(start: rangeStart, end: rangeEnd + 2)
                    result[prev, default: []].append(range)
                }
                currentCat = cat
                rangeStart = ts
                rangeEnd = ts
            }
        }
        if let prev = currentCat {
            let range = TimeRange(start: rangeStart, end: rangeEnd + 2)
            result[prev, default: []].append(range)
        }

        return result
    }

    /// Returns YouTube seconds for the last 7 days, zero-filled for days with no data.
    /// Result is ordered oldest to newest: [(dateString, seconds)]
    func weekYouTubeSummary() -> [(String, Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let cal = Calendar.current

        // Generate last 7 date strings (oldest first)
        var dateStrings: [String] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
            dateStrings.append(fmt.string(from: date))
        }

        // Query all youtube + shorts rows in range
        let rows: [(String, Int)] = db.query(
            "SELECT date, SUM(total_seconds) FROM daily_summaries WHERE category IN ('youtube', 'youtube_shorts') AND date >= ? AND date <= ? GROUP BY date",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, dateStrings.first!, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, dateStrings.last!, -1, SQLITE_TRANSIENT)
            },
            map: { stmt in
                let datePtr = sqlite3_column_text(stmt, 0)
                let dateStr = datePtr.map { String(cString: $0) } ?? ""
                let secs = Int(sqlite3_column_int(stmt, 1))
                return (dateStr, secs)
            }
        )

        let lookup = Dictionary(rows, uniquingKeysWith: { $1 })

        return dateStrings.map { dateStr in
            (dateStr, lookup[dateStr] ?? 0)
        }
    }

    /// Returns aggregated YouTube and working seconds for the past 6 days (not including today).
    func past6DaysBudgetData() -> (youtubeSeconds: Int, workingSeconds: Int) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        let cal = Calendar.current

        let today = fmt.string(from: Date())
        let sixDaysAgo = fmt.string(from: cal.date(byAdding: .day, value: -6, to: Date())!)

        let rows: [(String, Int)] = db.query(
            "SELECT category, SUM(total_seconds) FROM daily_summaries WHERE date >= ? AND date < ? GROUP BY category",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, sixDaysAgo, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, today, -1, SQLITE_TRANSIENT)
            },
            map: { stmt in
                let catPtr = sqlite3_column_text(stmt, 0)
                let cat = catPtr.map { String(cString: $0) } ?? ""
                let secs = Int(sqlite3_column_int(stmt, 1))
                return (cat, secs)
            }
        )

        var youtubeSeconds = 0
        var workingSeconds = 0
        for (cat, secs) in rows {
            switch cat {
            case "youtube", "youtube_shorts":
                youtubeSeconds += secs
            case "working":
                workingSeconds += secs
            default:
                break
            }
        }
        return (youtubeSeconds: youtubeSeconds, workingSeconds: workingSeconds)
    }

    /// Delete individual samples older than 7 days (summaries are kept)
    func rollupOldSamples() {
        let cutoff = Int(Date().timeIntervalSince1970) - (7 * 86400)
        db.run("DELETE FROM activity_samples WHERE timestamp < ?") { stmt in
            sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        }
        logger.info("Rolled up samples older than 7 days")
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }
}
