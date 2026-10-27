import AppKit

let size = 1024
guard let rep = NSBitmapImageRep(
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
    fatalError("Could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Could not create graphics context")
}
NSGraphicsContext.current = context

let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.20, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230).fill()

let inner = rect.insetBy(dx: 70, dy: 70)
NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.30, alpha: 1).setFill()
NSBezierPath(roundedRect: inner, xRadius: 180, yRadius: 180).fill()

let check = NSBezierPath()
check.lineWidth = 96
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: 270, y: 530))
check.line(to: NSPoint(x: 430, y: 360))
check.line(to: NSPoint(x: 760, y: 690))
NSColor(calibratedRed: 0.55, green: 0.60, blue: 0.98, alpha: 1).setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
try data.write(to: out)
print("Wrote \(out.path)")
