import AppKit

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(
    roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880),
    xRadius: 205,
    yRadius: 205
)
let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.08, green: 0.55, blue: 1.0, alpha: 1),
    ending: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.72, alpha: 1)
)!
gradient.draw(in: tile, angle: -90)

func roundedScreen(_ rect: NSRect, radius: CGFloat, lineWidth: CGFloat) {
    let screen = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    screen.lineWidth = lineWidth
    screen.lineJoinStyle = .round
    screen.stroke()
}

NSColor.white.setStroke()

// Original dual-display drawing. It intentionally uses ordinary geometry
// rather than an exported or rasterized SF Symbol.
roundedScreen(NSRect(x: 180, y: 395, width: 440, height: 285), radius: 42, lineWidth: 38)

let backStand = NSBezierPath()
backStand.lineWidth = 38
backStand.lineCapStyle = .round
backStand.move(to: NSPoint(x: 400, y: 395))
backStand.line(to: NSPoint(x: 400, y: 330))
backStand.move(to: NSPoint(x: 330, y: 330))
backStand.line(to: NSPoint(x: 470, y: 330))
backStand.stroke()

roundedScreen(NSRect(x: 430, y: 285, width: 410, height: 285), radius: 42, lineWidth: 38)

let frontStand = NSBezierPath()
frontStand.lineWidth = 38
frontStand.lineCapStyle = .round
frontStand.move(to: NSPoint(x: 635, y: 285))
frontStand.line(to: NSPoint(x: 635, y: 220))
frontStand.move(to: NSPoint(x: 565, y: 220))
frontStand.line(to: NSPoint(x: 705, y: 220))
frontStand.stroke()

NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count == 2,
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Usage: make_displaygate_icon.swift OUTPUT.png")
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
