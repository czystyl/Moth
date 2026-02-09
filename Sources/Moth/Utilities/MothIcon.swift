import AppKit

enum MothIcon {
    /// Resting moth — wings folded upward in a tent/V shape, narrow silhouette.
    /// Used when YouTube is not active.
    static let resting: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            let cx = w / 2
            let cy = h / 2

            ctx.setFillColor(NSColor.black.cgColor)

            // Body — narrow vertical ellipse
            let bodyW: CGFloat = 2.4
            let bodyH: CGFloat = 7.0
            ctx.fillEllipse(in: CGRect(
                x: cx - bodyW / 2, y: cy - bodyH / 2 - 1,
                width: bodyW, height: bodyH
            ))

            // Head
            let headR: CGFloat = 1.6
            ctx.fillEllipse(in: CGRect(
                x: cx - headR, y: cy + bodyH / 2 - 1 - 0.5,
                width: headR * 2, height: headR * 2
            ))

            // Antennae
            let antennaBase = CGPoint(x: cx, y: cy + bodyH / 2 + headR - 1)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.0)
            ctx.setLineCap(.round)

            // Left antenna
            ctx.move(to: antennaBase)
            ctx.addQuadCurve(to:
                CGPoint(x: cx - 4, y: h - 1),
                control: CGPoint(x: cx - 1, y: h - 2)
            )
            ctx.strokePath()

            // Right antenna
            ctx.move(to: antennaBase)
            ctx.addQuadCurve(to:
                CGPoint(x: cx + 4, y: h - 1),
                control: CGPoint(x: cx + 1, y: h - 2)
            )
            ctx.strokePath()

            // Wings folded upward — tent/V shape (left)
            let wingPath = CGMutablePath()
            wingPath.move(to: CGPoint(x: cx - 1, y: cy - 1))
            wingPath.addCurve(
                to: CGPoint(x: cx - 5.5, y: cy + 5),
                control1: CGPoint(x: cx - 4, y: cy - 1),
                control2: CGPoint(x: cx - 6.5, y: cy + 2)
            )
            wingPath.addCurve(
                to: CGPoint(x: cx - 1, y: cy + 3),
                control1: CGPoint(x: cx - 4.5, y: cy + 6),
                control2: CGPoint(x: cx - 2, y: cy + 5)
            )
            wingPath.closeSubpath()
            ctx.addPath(wingPath)
            ctx.fillPath()

            // Wings folded upward — tent/V shape (right)
            let wingPathR = CGMutablePath()
            wingPathR.move(to: CGPoint(x: cx + 1, y: cy - 1))
            wingPathR.addCurve(
                to: CGPoint(x: cx + 5.5, y: cy + 5),
                control1: CGPoint(x: cx + 4, y: cy - 1),
                control2: CGPoint(x: cx + 6.5, y: cy + 2)
            )
            wingPathR.addCurve(
                to: CGPoint(x: cx + 1, y: cy + 3),
                control1: CGPoint(x: cx + 4.5, y: cy + 6),
                control2: CGPoint(x: cx + 2, y: cy + 5)
            )
            wingPathR.closeSubpath()
            ctx.addPath(wingPathR)
            ctx.fillPath()

            return true
        }
        img.isTemplate = true
        return img
    }()

    /// Active moth — wings fully spread, wide horizontal silhouette.
    /// Used when YouTube is detected. Rendered in the given color (non-template).
    static func active(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let w = rect.width
            let h = rect.height
            let cx = w / 2
            let cy = h / 2

            ctx.setFillColor(color.cgColor)

            // Body — narrow vertical ellipse
            let bodyW: CGFloat = 2.4
            let bodyH: CGFloat = 6.5
            ctx.fillEllipse(in: CGRect(
                x: cx - bodyW / 2, y: cy - bodyH / 2,
                width: bodyW, height: bodyH
            ))

            // Head
            let headR: CGFloat = 1.6
            ctx.fillEllipse(in: CGRect(
                x: cx - headR, y: cy + bodyH / 2 - 0.5,
                width: headR * 2, height: headR * 2
            ))

            // Antennae
            let antennaBase = CGPoint(x: cx, y: cy + bodyH / 2 + headR)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(1.0)
            ctx.setLineCap(.round)

            // Left antenna
            ctx.move(to: antennaBase)
            ctx.addQuadCurve(to:
                CGPoint(x: cx - 5, y: h - 1),
                control: CGPoint(x: cx - 2, y: h - 1)
            )
            ctx.strokePath()

            // Right antenna
            ctx.move(to: antennaBase)
            ctx.addQuadCurve(to:
                CGPoint(x: cx + 5, y: h - 1),
                control: CGPoint(x: cx + 2, y: h - 1)
            )
            ctx.strokePath()

            // Upper wings — spread wide
            // Left upper wing
            let ulWing = CGMutablePath()
            ulWing.move(to: CGPoint(x: cx - 1, y: cy + 1))
            ulWing.addCurve(
                to: CGPoint(x: 1, y: cy + 5),
                control1: CGPoint(x: cx - 4, y: cy + 4),
                control2: CGPoint(x: 1, y: cy + 7)
            )
            ulWing.addCurve(
                to: CGPoint(x: cx - 1, y: cy - 1),
                control1: CGPoint(x: 2, y: cy + 2),
                control2: CGPoint(x: cx - 3, y: cy)
            )
            ulWing.closeSubpath()
            ctx.addPath(ulWing)
            ctx.fillPath()

            // Right upper wing
            let urWing = CGMutablePath()
            urWing.move(to: CGPoint(x: cx + 1, y: cy + 1))
            urWing.addCurve(
                to: CGPoint(x: w - 1, y: cy + 5),
                control1: CGPoint(x: cx + 4, y: cy + 4),
                control2: CGPoint(x: w - 1, y: cy + 7)
            )
            urWing.addCurve(
                to: CGPoint(x: cx + 1, y: cy - 1),
                control1: CGPoint(x: w - 2, y: cy + 2),
                control2: CGPoint(x: cx + 3, y: cy)
            )
            urWing.closeSubpath()
            ctx.addPath(urWing)
            ctx.fillPath()

            // Lower wings — smaller, spread downward
            // Left lower wing
            let llWing = CGMutablePath()
            llWing.move(to: CGPoint(x: cx - 1, y: cy))
            llWing.addCurve(
                to: CGPoint(x: 3, y: cy - 4),
                control1: CGPoint(x: cx - 3, y: cy - 1),
                control2: CGPoint(x: 2, y: cy - 1)
            )
            llWing.addCurve(
                to: CGPoint(x: cx - 1, y: cy - 2.5),
                control1: CGPoint(x: 4, y: cy - 5.5),
                control2: CGPoint(x: cx - 2, y: cy - 4)
            )
            llWing.closeSubpath()
            ctx.addPath(llWing)
            ctx.fillPath()

            // Right lower wing
            let rlWing = CGMutablePath()
            rlWing.move(to: CGPoint(x: cx + 1, y: cy))
            rlWing.addCurve(
                to: CGPoint(x: w - 3, y: cy - 4),
                control1: CGPoint(x: cx + 3, y: cy - 1),
                control2: CGPoint(x: w - 2, y: cy - 1)
            )
            rlWing.addCurve(
                to: CGPoint(x: cx + 1, y: cy - 2.5),
                control1: CGPoint(x: w - 4, y: cy - 5.5),
                control2: CGPoint(x: cx + 2, y: cy - 4)
            )
            rlWing.closeSubpath()
            ctx.addPath(rlWing)
            ctx.fillPath()

            return true
        }
        img.isTemplate = false
        return img
    }
}
