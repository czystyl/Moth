import Foundation
import os

private let logger = Logger(subsystem: "com.moth", category: "NowPlayingDetector")

/// Detects media playback using macOS MediaRemote private framework via the Swift interpreter.
///
/// Compiled binaries can't access MediaRemote (XPC restriction on ad-hoc signed binaries),
/// but the Apple-signed Swift interpreter can. We shell out to `swift` with a helper script
/// on a background timer every 2s and cache the result. Callers read the cached state instantly.
struct NowPlayingDetector {
    struct NowPlayingState {
        let bundleIdentifier: String
        let isPlaying: Bool
        let title: String
        let duration: Double  // seconds, 0 if unknown
        let elapsed: Double   // seconds, 0 if unknown
    }

    // MARK: - Cached state (thread-safe via cacheQueue)

    private static let cacheQueue = DispatchQueue(label: "com.moth.nowplaying.cache")
    private static var _cachedState: NowPlayingState?
    private static var _started = false

    /// The most recent "Now Playing" state, or nil if nothing is playing.
    /// Always returns immediately — never blocks.
    static var cachedState: NowPlayingState? {
        cacheQueue.sync { _cachedState }
    }

    /// Call once at app launch to start the background refresh timer.
    static func startPolling() {
        cacheQueue.sync {
            guard !_started else { return }
            _started = true
        }

        writeHelperScript()

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now() + 0.1, repeating: 2.0)
        timer.setEventHandler { refreshNowPlaying() }
        timer.resume()
        _timerSource = timer
        logger.info("Now Playing polling started")
    }

    // MARK: - Private

    private static var _timerSource: DispatchSourceTimer?
    private static let pollQueue = DispatchQueue(label: "com.moth.nowplaying.poll")

    private static let scriptPath: String = {
        let dir = NSTemporaryDirectory()
        return (dir as NSString).appendingPathComponent("moth_nowplaying.swift")
    }()

    private static let helperScript = """
    import Foundation
    guard let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else { print("||"); exit(0) }
    typealias F1 = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    typealias F2 = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
    guard let p1 = dlsym(h, "MRMediaRemoteGetNowPlayingInfo"),
          let p2 = dlsym(h, "MRMediaRemoteGetNowPlayingClient") else { print("||"); exit(0) }
    let getInfo = unsafeBitCast(p1, to: F1.self)
    let getClient = unsafeBitCast(p2, to: F2.self)
    var rate = 0.0, title = "", bundleId = "", duration = 0.0, elapsed = 0.0
    let s1 = DispatchSemaphore(value: 0)
    getInfo(DispatchQueue.global()) { info in
        rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
        title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
        elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        s1.signal()
    }
    s1.wait()
    let s2 = DispatchSemaphore(value: 0)
    getClient(DispatchQueue.global()) { client in
        if let client,
           client.responds(to: NSSelectorFromString("bundleIdentifier")),
           let bid = client.perform(NSSelectorFromString("bundleIdentifier"))?.takeUnretainedValue() as? String {
            bundleId = bid
        }
        s2.signal()
    }
    s2.wait()
    print("\\(bundleId)|\\(rate)|\\(duration)|\\(elapsed)|\\(title)")
    """

    private static func writeHelperScript() {
        try? helperScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
    }

    private static func refreshNowPlaying() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [scriptPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch swift helper: \(error.localizedDescription)")
            return
        }

        // Read pipe before waitUntilExit to avoid deadlock on large output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return }

        let output = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            cacheQueue.sync { _cachedState = nil }
            return
        }

        // Parse "bundleId|rate|duration|elapsed|title"
        let parts = output.components(separatedBy: "|")
        guard parts.count >= 5 else {
            cacheQueue.sync { _cachedState = nil }
            return
        }

        let bundleId = parts[0]
        let rate = Double(parts[1]) ?? 0
        let duration = Double(parts[2]) ?? 0
        let elapsed = Double(parts[3]) ?? 0
        let title = parts[4...].joined(separator: "|") // title may contain |

        let newState: NowPlayingState? = bundleId.isEmpty ? nil : NowPlayingState(
            bundleIdentifier: bundleId,
            isPlaying: rate > 0,
            title: title,
            duration: duration,
            elapsed: elapsed
        )

        let oldState: NowPlayingState? = cacheQueue.sync { _cachedState }
        let changed = oldState?.bundleIdentifier != newState?.bundleIdentifier
            || oldState?.isPlaying != newState?.isPlaying
            || oldState?.title != newState?.title
        if changed {
            if let s = newState {
                logger.info("Now Playing: \(s.bundleIdentifier) playing=\(s.isPlaying) duration=\(s.duration) elapsed=\(s.elapsed) title=\(s.title)")
            } else {
                logger.info("Now Playing: nothing")
            }
        }

        cacheQueue.sync { _cachedState = newState }
    }
}
