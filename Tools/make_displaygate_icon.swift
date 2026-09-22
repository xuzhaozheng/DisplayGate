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
    roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
    xRadius: 238,
    yRadius: 238
)
let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.08, green: 0.55, blue: 1.0, alpha: 1),
    ending: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.72, alpha: 1)
)!
gradient.draw(in: tile, angle: -90)

let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 430, weight: .medium)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
guard let symbol = NSImage(systemSymbolName: "display.2", accessibilityDescription: "DisplayGate")?
    .withSymbolConfiguration(symbolConfiguration) else {
    fatalError("Unable to load display.2 SF Symbol")
}

let symbolSize = symbol.size
let scale = min(756 / symbolSize.width, 559 / symbolSize.height)
let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
let drawRect = NSRect(
    x: (CGFloat(size) - drawSize.width) / 2,
    y: (CGFloat(size) - drawSize.height) / 2,
    width: drawSize.width,
    height: drawSize.height
)
symbol.draw(in: drawRect)

NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count == 2,
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Usage: make_displaygate_icon.swift OUTPUT.png")
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
