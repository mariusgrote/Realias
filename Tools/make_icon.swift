// Draws Resources/Realias.icns. Run with ./Tools/make_icon.sh after editing.
// A Finder-style alias badge overlays the tail of a sweeping white arrow.
import AppKit

func drawIcon(size s: CGFloat, into ctx: CGContext) {
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // macOS app icons sit inset in their canvas with a squircle-ish corner.
    let inset = s * 0.088
    let side = s - inset * 2
    let rect = CGRect(x: inset, y: inset, width: side, height: side)
    let plate = CGPath(roundedRect: rect, cornerWidth: side * 0.2246,
                       cornerHeight: side * 0.2246, transform: nil)

    ctx.saveGState()
    ctx.addPath(plate)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.42, 0.62, 1.00, 1])!,
        CGColor(colorSpace: space, components: [0.11, 0.27, 0.80, 1])!,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: rect.maxY),
                           end: CGPoint(x: 0, y: rect.minY),
                           options: [])
    ctx.restoreGState()

    // Everything below is in the plate's unit square, so one set of numbers
    // works at every size.
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * side, y: rect.minY + y * side)
    }

    // A short, upright tail restores the tighter diagonal sweep. The badge
    // overlaps its left edge rather than lining up with the white stem.
    let route = CGMutablePath()
    route.move(to: p(0.34, 0.32))
    route.addCurve(to: p(0.68, 0.70),
                   control1: p(0.34, 0.56), control2: p(0.50, 0.52))
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(side * 0.095)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(route)
    ctx.strokePath()

    let head = CGMutablePath()
    head.move(to: p(0.80, 0.82))
    head.addLine(to: p(0.74, 0.58))
    head.addLine(to: p(0.56, 0.76))
    head.closeSubpath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(head)
    ctx.fillPath()

    // A compact Finder-style badge: a short upward hook and square outer
    // head edges. Its head overlaps the side of the white tail, in front.
    let badge = CGMutablePath()
    badge.move(to: p(0.175, 0.18))
    badge.addCurve(to: p(0.25, 0.305),
                   control1: p(0.175, 0.235), control2: p(0.205, 0.28))
    badge.addLine(to: p(0.215, 0.34))
    badge.addLine(to: p(0.31, 0.34))
    badge.addLine(to: p(0.31, 0.245))
    badge.addLine(to: p(0.275, 0.28))
    badge.addCurve(to: p(0.175, 0.18),
                   control1: p(0.23, 0.26), control2: p(0.195, 0.22))
    badge.closeSubpath()
    ctx.setLineJoin(.round)
    ctx.setLineWidth(side * 0.014)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setFillColor(NSColor(white: 0.13, alpha: 1).cgColor)
    ctx.addPath(badge)
    ctx.drawPath(using: .fillStroke)

}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32),
                   ("icon_32x32", 32), ("icon_32x32@2x", 64),
                   ("icon_128x128", 128), ("icon_128x128@2x", 256),
                   ("icon_256x256", 256), ("icon_256x256@2x", 512),
                   ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    drawIcon(size: CGFloat(px), into: gc.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: out.appendingPathComponent("\(name).png"))
}
