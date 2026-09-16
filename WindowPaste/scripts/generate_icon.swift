import AppKit
import Foundation

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
    ("icon_512x512@2x", 1024)
]

guard CommandLine.arguments.count > 1 else {
    fputs("usage: generate_icon.swift <output-dir> [master-png]\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let defaultMaster = scriptDir.deletingLastPathComponent().appendingPathComponent("Design/AppIcon-1024.png")
let masterURL = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : defaultMaster

guard let master = NSImage(contentsOf: masterURL),
      let source = master.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("missing master icon at \(masterURL.path)\n", stderr)
    exit(1)
}

for item in sizes {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: item.size,
        pixelsHigh: item.size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        continue
    }
    rep.size = NSSize(width: item.size, height: item.size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: item.size, height: item.size)
    NSImage(cgImage: source, size: rect.size).draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: output.appendingPathComponent("\(item.name).png"))
}

print("wrote icons to \(output.path)")
