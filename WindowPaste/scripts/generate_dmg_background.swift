import AppKit
import Foundation

let pointSize = NSSize(width: 660, height: 420)
let scale: CGFloat = 2
let pixels = NSSize(width: pointSize.width * scale, height: pointSize.height * scale)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixels.width),
    pixelsHigh: Int(pixels.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap\n", stderr)
    exit(1)
}
rep.size = pointSize

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("failed to create graphics context\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true

let bounds = NSRect(origin: .zero, size: pointSize)

NSColor(calibratedRed: 0.027, green: 0.078, blue: 0.067, alpha: 1).setFill()
bounds.fill()

let glow = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.18, green: 0.83, blue: 0.75, alpha: 0.22),
        NSColor(calibratedRed: 0.05, green: 0.16, blue: 0.14, alpha: 0)
    ]
)
glow?.draw(
    fromCenter: NSPoint(x: bounds.midX, y: 310),
    radius: 0,
    toCenter: NSPoint(x: bounds.midX, y: 310),
    radius: 280,
    options: []
)

func pad(at x: CGFloat) {
    let rect = NSRect(x: x - 78, y: 148, width: 156, height: 168)
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.20, alpha: 0.55).setFill()
    path.fill()
    NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 0.18).setStroke()
    path.lineWidth = 1.5
    path.stroke()
}

pad(at: 180)
pad(at: 480)

let arrowY: CGFloat = 232
let start = NSPoint(x: 268, y: arrowY)
let end = NSPoint(x: 392, y: arrowY)
let arrow = NSBezierPath()
arrow.move(to: start)
arrow.line(to: NSPoint(x: end.x - 18, y: end.y))
arrow.lineWidth = 6
arrow.lineCapStyle = .round
NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 0.95).setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: end.x - 22, y: end.y + 14))
head.line(to: end)
head.line(to: NSPoint(x: end.x - 22, y: end.y - 14))
head.lineWidth = 6
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

let title = "拖到“应用程序”即可安装" as NSString
let titleFont = NSFont(name: "PingFangSC-Medium", size: 18)
    ?? NSFont.systemFont(ofSize: 18, weight: .medium)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedRed: 0.84, green: 0.98, blue: 0.94, alpha: 0.95)
]
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(
    at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: 58),
    withAttributes: titleAttrs
)

let subtitle = "把「窗贴」拖进右侧文件夹" as NSString
let subtitleFont = NSFont(name: "PingFangSC-Regular", size: 13)
    ?? NSFont.systemFont(ofSize: 13, weight: .regular)
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor(calibratedRed: 0.56, green: 0.67, blue: 0.64, alpha: 1)
]
let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
subtitle.draw(
    at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: 34),
    withAttributes: subtitleAttrs
)

NSGraphicsContext.restoreGraphicsState()

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let outputDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : scriptDir.deletingLastPathComponent().appendingPathComponent("Design")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let pngURL = outputDir.appendingPathComponent("dmg-background.png")
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}
try png.write(to: pngURL)
print("wrote \(pngURL.path)")
