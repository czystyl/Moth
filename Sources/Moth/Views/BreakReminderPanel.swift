import AppKit

/// Floating always-on-top panel for break reminders.
/// Bypasses Focus mode / Do Not Disturb since it's a window, not a notification.
@MainActor
enum BreakReminderPanel {
    enum Severity: CustomStringConvertible {
        case gentle, warning, critical

        var title: String {
            switch self {
            case .gentle: return "Take a Break"
            case .warning: return "Time to Stop"
            case .critical: return "Stop Watching"
            }
        }

        var icon: String {
            switch self {
            case .gentle: return "pause.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }

        var accentColor: NSColor {
            switch self {
            case .gentle: return .systemOrange
            case .warning: return .systemOrange
            case .critical: return .systemRed
            }
        }

        var description: String {
            switch self {
            case .gentle: return "gentle"
            case .warning: return "warning"
            case .critical: return "critical"
            }
        }
    }

    private static var panel: NSPanel?

    static func show(
        severity: Severity,
        body: String,
        videoSeconds: Int,
        shortsSeconds: Int,
        budgetRemainingSeconds: Int,
        earnedSeconds: Int
    ) {
        panel?.close()

        let width: CGFloat = 420
        let height: CGFloat = 220

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.becomesKeyOnlyIfNeeded = true
        p.isOpaque = false
        p.backgroundColor = .clear

        // --- Root view with rounded background ---
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        root.wantsLayer = true
        root.layer?.cornerRadius = 16
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // --- Top accent band ---
        let bandHeight: CGFloat = 64
        let band = NSView(frame: NSRect(x: 0, y: height - bandHeight, width: width, height: bandHeight))
        band.wantsLayer = true
        band.layer?.backgroundColor = severity.accentColor.withAlphaComponent(0.15).cgColor
        root.addSubview(band)

        // --- Icon ---
        let iconSize: CGFloat = 32
        let iconView = NSImageView(frame: NSRect(x: 20, y: height - bandHeight / 2 - iconSize / 2, width: iconSize, height: iconSize))
        if let img = NSImage(systemSymbolName: severity.icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = severity.accentColor
        }
        root.addSubview(iconView)

        // --- Title ---
        let titleLabel = NSTextField(labelWithString: severity.title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 62, y: height - bandHeight / 2 - 12, width: 200, height: 24)
        root.addSubview(titleLabel)

        // --- Body ---
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.frame = NSRect(x: 20, y: height - bandHeight - 36, width: width - 40, height: 18)
        root.addSubview(bodyLabel)

        // --- Stats row ---
        let statsY: CGFloat = height - bandHeight - 80
        let cols = 4
        let padding: CGFloat = 20
        let gap: CGFloat = 8
        let statWidth = (width - padding * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)

        func addStat(col: Int, value: String, label: String, color: NSColor) {
            let x = padding + CGFloat(col) * (statWidth + gap)

            let valLabel = NSTextField(labelWithString: value)
            valLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
            valLabel.textColor = color
            valLabel.frame = NSRect(x: x, y: statsY, width: statWidth, height: 22)
            valLabel.alignment = .center
            root.addSubview(valLabel)

            let descLabel = NSTextField(labelWithString: label)
            descLabel.font = .systemFont(ofSize: 9, weight: .medium)
            descLabel.textColor = .tertiaryLabelColor
            descLabel.frame = NSRect(x: x, y: statsY - 14, width: statWidth, height: 12)
            descLabel.alignment = .center
            root.addSubview(descLabel)
        }

        addStat(col: 0, value: TimeFormatter.format(seconds: videoSeconds), label: "VIDEOS", color: severity.accentColor)
        addStat(col: 1, value: TimeFormatter.format(seconds: shortsSeconds), label: "SHORTS", color: severity.accentColor)
        addStat(col: 2, value: TimeFormatter.format(seconds: earnedSeconds), label: "EARNED", color: .systemGreen)

        let budgetColor: NSColor = budgetRemainingSeconds < 0 ? .systemRed : .systemGreen
        let budgetText = budgetRemainingSeconds < 0
            ? "-\(TimeFormatter.format(seconds: abs(budgetRemainingSeconds)))"
            : TimeFormatter.format(seconds: budgetRemainingSeconds)
        addStat(col: 3, value: budgetText, label: "REMAINING", color: budgetColor)

        // --- Separator ---
        let sep = NSView(frame: NSRect(x: 20, y: 50, width: width - 40, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        root.addSubview(sep)

        // --- Dismiss button ---
        let button = NSButton(title: "Dismiss", target: p, action: #selector(NSPanel.close))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.frame = NSRect(x: width / 2 - 60, y: 12, width: 120, height: 30)
        root.addSubview(button)

        p.contentView = root

        // Center on screen
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: sf.midX - width / 2, y: sf.midY - height / 2))
        }

        p.orderFrontRegardless()
        panel = p

        // Auto-dismiss after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak p] in
            p?.close()
        }
    }
}
