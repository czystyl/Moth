import Foundation
import os

private let logger = Logger(subsystem: "com.moth", category: "ArcBrowserDetector")

struct ArcBrowserDetector {
    private static let arcBundleID = "company.thebrowser.Browser"
    private static let shortsMaxDuration: Double = 61 // Shorts are ≤60s

    // State for loop detection (accessed on main actor via ActivityMonitor's poll)
    private static var lastTitle: String = ""
    private static var lastElapsed: Double = 0
    private static var maxElapsedForTitle: Double = 0
    private static var loopDetected: Bool = false

    /// Returns whether Arc is playing YouTube, the media title, and whether it's a Short.
    static func detect() -> (isPlaying: Bool, title: String, isShort: Bool) {
        guard let state = NowPlayingDetector.cachedState else {
            resetTracking()
            return (false, "", false)
        }
        let playing = state.bundleIdentifier == arcBundleID && state.isPlaying
        guard playing else {
            resetTracking()
            return (false, "", false)
        }

        let isShort = classifyShort(state: state)
        return (true, state.title, isShort)
    }

    private static func classifyShort(state: NowPlayingDetector.NowPlayingState) -> Bool {
        // Method 1: Duration is reported and short
        if state.duration > 0 && state.duration <= shortsMaxDuration {
            return true
        }

        // Method 2: Loop detection via elapsed time
        let titleChanged = state.title != lastTitle

        if titleChanged {
            // New title — reset tracking
            lastTitle = state.title
            lastElapsed = state.elapsed
            maxElapsedForTitle = state.elapsed
            loopDetected = false
            return false
        }

        // Same title — track elapsed
        if state.elapsed < lastElapsed - 1.0 {
            // Elapsed went backwards → loop detected
            if maxElapsedForTitle <= shortsMaxDuration && maxElapsedForTitle > 0 {
                loopDetected = true
                logger.info("Short detected via loop: maxElapsed=\(maxElapsedForTitle) title=\(state.title)")
            }
        }

        maxElapsedForTitle = max(maxElapsedForTitle, state.elapsed)
        lastElapsed = state.elapsed

        // If we've seen elapsed go past 61s, it's not a Short
        if maxElapsedForTitle > shortsMaxDuration {
            loopDetected = false
            return false
        }

        return loopDetected
    }

    private static func resetTracking() {
        lastTitle = ""
        lastElapsed = 0
        maxElapsedForTitle = 0
        loopDetected = false
    }
}
