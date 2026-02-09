#!/usr/bin/env swift

import AppKit
import Foundation

// Generate Moth app icon: gradient circle (red→orange) with a white moth silhouette

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let iconsetDir = "build/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    return NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Background: red→orange gradient circle
        let colors = [
            NSColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1).cgColor,
            NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1).cgColor,
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let inset = s * 0.04
        let circleRect = rect.insetBy(dx: inset, dy: inset)
        ctx.addEllipse(in: circleRect)
        ctx.clip()

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: s),
                end: CGPoint(x: s, y: 0),
                options: []
            )
        }

        ctx.resetClip()

        // Moth silhouette in white
        let center = CGPoint(x: s / 2, y: s / 2)

        // Subtle radial glow behind the moth
        let glowColors = [
            NSColor(white: 1, alpha: 0.25).cgColor,
            NSColor(white: 1, alpha: 0).cgColor,
        ] as CFArray
        if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0, 1]) {
            ctx.drawRadialGradient(
                glow,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: s * 0.35,
                options: []
            )
        }

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.setStrokeColor(NSColor.white.cgColor)

        // Body — elongated vertical ellipse
        let bodyW = s * 0.07
        let bodyH = s * 0.30
        let bodyY = center.y - bodyH * 0.45
        ctx.fillEllipse(in: CGRect(
            x: center.x - bodyW / 2, y: bodyY,
            width: bodyW, height: bodyH
        ))

        // Head
        let headR = s * 0.04
        let headY = bodyY + bodyH
        ctx.fillEllipse(in: CGRect(
            x: center.x - headR, y: headY - headR * 0.3,
            width: headR * 2, height: headR * 2
        ))

        // Antennae
        let antennaBase = CGPoint(x: center.x, y: headY + headR * 1.5)
        ctx.setLineWidth(s * 0.015)
        ctx.setLineCap(.round)

        ctx.move(to: antennaBase)
        ctx.addQuadCurve(to:
            CGPoint(x: center.x - s * 0.15, y: center.y + s * 0.35),
            control: CGPoint(x: center.x - s * 0.04, y: center.y + s * 0.32)
        )
        ctx.strokePath()

        ctx.move(to: antennaBase)
        ctx.addQuadCurve(to:
            CGPoint(x: center.x + s * 0.15, y: center.y + s * 0.35),
            control: CGPoint(x: center.x + s * 0.04, y: center.y + s * 0.32)
        )
        ctx.strokePath()

        // Upper wings — large, spread wide
        let ulWing = CGMutablePath()
        ulWing.move(to: CGPoint(x: center.x - bodyW / 2, y: center.y + bodyH * 0.1))
        ulWing.addCurve(
            to: CGPoint(x: center.x - s * 0.38, y: center.y + s * 0.22),
            control1: CGPoint(x: center.x - s * 0.18, y: center.y + s * 0.25),
            control2: CGPoint(x: center.x - s * 0.35, y: center.y + s * 0.32)
        )
        ulWing.addCurve(
            to: CGPoint(x: center.x - bodyW / 2, y: center.y - bodyH * 0.15),
            control1: CGPoint(x: center.x - s * 0.40, y: center.y + s * 0.08),
            control2: CGPoint(x: center.x - s * 0.20, y: center.y - s * 0.05)
        )
        ulWing.closeSubpath()
        ctx.addPath(ulWing)
        ctx.fillPath()

        let urWing = CGMutablePath()
        urWing.move(to: CGPoint(x: center.x + bodyW / 2, y: center.y + bodyH * 0.1))
        urWing.addCurve(
            to: CGPoint(x: center.x + s * 0.38, y: center.y + s * 0.22),
            control1: CGPoint(x: center.x + s * 0.18, y: center.y + s * 0.25),
            control2: CGPoint(x: center.x + s * 0.35, y: center.y + s * 0.32)
        )
        urWing.addCurve(
            to: CGPoint(x: center.x + bodyW / 2, y: center.y - bodyH * 0.15),
            control1: CGPoint(x: center.x + s * 0.40, y: center.y + s * 0.08),
            control2: CGPoint(x: center.x + s * 0.20, y: center.y - s * 0.05)
        )
        urWing.closeSubpath()
        ctx.addPath(urWing)
        ctx.fillPath()

        // Lower wings — smaller, angled downward
        let llWing = CGMutablePath()
        llWing.move(to: CGPoint(x: center.x - bodyW / 2, y: center.y - bodyH * 0.05))
        llWing.addCurve(
            to: CGPoint(x: center.x - s * 0.25, y: center.y - s * 0.22),
            control1: CGPoint(x: center.x - s * 0.14, y: center.y - s * 0.05),
            control2: CGPoint(x: center.x - s * 0.24, y: center.y - s * 0.10)
        )
        llWing.addCurve(
            to: CGPoint(x: center.x - bodyW / 2, y: center.y - bodyH * 0.25),
            control1: CGPoint(x: center.x - s * 0.22, y: center.y - s * 0.28),
            control2: CGPoint(x: center.x - s * 0.10, y: center.y - s * 0.22)
        )
        llWing.closeSubpath()
        ctx.addPath(llWing)
        ctx.fillPath()

        let rlWing = CGMutablePath()
        rlWing.move(to: CGPoint(x: center.x + bodyW / 2, y: center.y - bodyH * 0.05))
        rlWing.addCurve(
            to: CGPoint(x: center.x + s * 0.25, y: center.y - s * 0.22),
            control1: CGPoint(x: center.x + s * 0.14, y: center.y - s * 0.05),
            control2: CGPoint(x: center.x + s * 0.24, y: center.y - s * 0.10)
        )
        rlWing.addCurve(
            to: CGPoint(x: center.x + bodyW / 2, y: center.y - bodyH * 0.25),
            control1: CGPoint(x: center.x + s * 0.22, y: center.y - s * 0.28),
            control2: CGPoint(x: center.x + s * 0.10, y: center.y - s * 0.22)
        )
        rlWing.closeSubpath()
        ctx.addPath(rlWing)
        ctx.fillPath()

        // Wing eye-spots (subtle circles on upper wings)
        let spotR = s * 0.025
        let spotAlpha: CGFloat = 0.3
        ctx.setFillColor(NSColor(red: 0.9, green: 0.15, blue: 0.1, alpha: spotAlpha).cgColor)
        ctx.fillEllipse(in: CGRect(
            x: center.x - s * 0.22 - spotR, y: center.y + s * 0.12 - spotR,
            width: spotR * 2, height: spotR * 2
        ))
        ctx.fillEllipse(in: CGRect(
            x: center.x + s * 0.22 - spotR, y: center.y + s * 0.12 - spotR,
            width: spotR * 2, height: spotR * 2
        ))

        return true
    }
}

for entry in sizes {
    let image = renderIcon(size: entry.size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        print("Failed to render \(entry.name)")
        exit(1)
    }
    let path = "\(iconsetDir)/\(entry.name).png"
    try pngData.write(to: URL(fileURLWithPath: path))
}

print("Generated iconset at \(iconsetDir)")
