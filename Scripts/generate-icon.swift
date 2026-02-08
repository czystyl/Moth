#!/usr/bin/env swift

import AppKit
import Foundation

// Generate Moth app icon: gradient circle (red→orange) with a white clock symbol

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

        // Clock circle (white outline)
        let clockRadius = s * 0.28
        let center = CGPoint(x: s / 2, y: s / 2)
        let lineWidth = s * 0.06

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(
            center: center,
            radius: clockRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        ctx.strokePath()

        // Clock hands
        ctx.setLineCap(.round)

        // Hour hand (pointing to 10 o'clock)
        let hourAngle = CGFloat.pi / 2 + CGFloat.pi / 3 // 10 o'clock
        let hourLength = clockRadius * 0.5
        ctx.setLineWidth(lineWidth * 1.2)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(
            x: center.x + cos(hourAngle) * hourLength,
            y: center.y + sin(hourAngle) * hourLength
        ))
        ctx.strokePath()

        // Minute hand (pointing to 12 o'clock)
        let minuteAngle = CGFloat.pi / 2
        let minuteLength = clockRadius * 0.7
        ctx.setLineWidth(lineWidth * 0.8)
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(
            x: center.x + cos(minuteAngle) * minuteLength,
            y: center.y + sin(minuteAngle) * minuteLength
        ))
        ctx.strokePath()

        // Center dot
        let dotSize = lineWidth * 1.2
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize,
            height: dotSize
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
