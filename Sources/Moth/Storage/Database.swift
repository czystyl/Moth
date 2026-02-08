import Foundation
import SQLite3
import os

private let logger = Logger(subsystem: "com.moth", category: "Database")

final class Database {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.moth.database", qos: .utility)

    static let shared = Database()

    private init() {}

    var isOpen: Bool { db != nil }

    func open() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let dir = appSupport.appendingPathComponent("Moth", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Migrate from old Deyup location if needed
        migrateFromDeyup(appSupport: appSupport, newDir: dir)

        let path = dir.appendingPathComponent("moth.sqlite").path

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw DatabaseError.openFailed(msg)
        }

        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA busy_timeout=5000")
    }

    func close() {
        queue.sync {
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
        }
    }

    func exec(_ sql: String) {
        queue.sync {
            guard let db else {
                logger.error("exec called with nil db")
                return
            }
            var err: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
                let msg = err.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(err)
                logger.error("exec error: \(msg, privacy: .public) — SQL: \(sql, privacy: .public)")
            }
        }
    }

    func run(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) {
        queue.sync {
            guard let db else {
                logger.error("run called with nil db")
                return
            }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logger.error("prepare error: \(String(cString: sqlite3_errmsg(db)), privacy: .public)")
                return
            }
            defer { sqlite3_finalize(stmt) }

            bind?(stmt!)
            if sqlite3_step(stmt) != SQLITE_DONE {
                logger.error("step error: \(String(cString: sqlite3_errmsg(db)), privacy: .public)")
            }
        }
    }

    func query<T>(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil, map: (OpaquePointer) -> T) -> [T] {
        queue.sync {
            guard let db else {
                logger.error("query called with nil db")
                return []
            }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logger.error("prepare error: \(String(cString: sqlite3_errmsg(db)), privacy: .public)")
                return []
            }
            defer { sqlite3_finalize(stmt) }

            bind?(stmt!)

            var results: [T] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(map(stmt!))
            }
            return results
        }
    }

    // MARK: - Migration

    private func migrateFromDeyup(appSupport: URL, newDir: URL) {
        let fm = FileManager.default
        let oldDir = appSupport.appendingPathComponent("Deyup", isDirectory: true)
        let oldDB = oldDir.appendingPathComponent("deyup.sqlite")
        let newDB = newDir.appendingPathComponent("moth.sqlite")

        guard fm.fileExists(atPath: oldDB.path), !fm.fileExists(atPath: newDB.path) else { return }

        logger.info("Migrating database from Deyup to Moth")

        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let src = oldDir.appendingPathComponent("deyup.sqlite\(suffix)")
            let dst = newDir.appendingPathComponent("moth.sqlite\(suffix)")
            guard fm.fileExists(atPath: src.path) else { continue }
            do {
                try fm.moveItem(at: src, to: dst)
                logger.info("Migrated \(src.lastPathComponent)")
            } catch {
                logger.error("Failed to migrate \(src.lastPathComponent): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

enum DatabaseError: Error {
    case openFailed(String)
}
