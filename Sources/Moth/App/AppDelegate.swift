import AppKit
import ServiceManagement
import os

private let logger = Logger(subsystem: "com.moth", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    var monitor: ActivityMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NowPlayingDetector.startPolling()

        let center = NSWorkspace.shared.notificationCenter

        // Sleep / wake
        center.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Screen lock / unlock
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        dnc.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("App terminating, closing database")
        Database.shared.close()
    }

    @objc private func handleSleep() {
        logger.info("System going to sleep, pausing monitor")
        Task { @MainActor in
            monitor?.stop()
        }
    }

    @objc private func handleWake() {
        logger.info("System woke up, resuming monitor")
        Task { @MainActor in
            monitor?.screenLocked = false
            monitor?.start()
        }
    }

    @objc private func handleScreenLock() {
        logger.info("Screen locked, marking idle")
        Task { @MainActor in
            monitor?.screenLocked = true
        }
    }

    @objc private func handleScreenUnlock() {
        logger.info("Screen unlocked")
        Task { @MainActor in
            monitor?.screenLocked = false
        }
    }

    static func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                logger.info("Launch at login enabled")
            } catch {
                logger.error("Failed to enable launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
