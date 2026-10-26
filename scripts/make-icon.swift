import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func render(size: Int, filename: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let outer = NSBezierPath(roundedRect: NSRect(x: 66, y: 66, width: 892, height: 892), xRadius: 210, yRadius: 210)
    NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.94, alpha: 1).setFill()
    outer.fill()
    let tile = NSBezierPath(roundedRect: NSRect(x: 182, y: 182, width: 660, height: 660), xRadius: 176, yRadius: 176)
    NSColor(calibratedRed: 0.39, green: 0.35, blue: 0.76, alpha: 1).setFill()
    tile.fill()
    let heights: [CGFloat] = [105, 220, 345, 440, 295, 185, 85]
    NSColor.white.setFill()
    for (i, height) in heights.enumerated() {
        let bar = NSBezierPath(roundedRect: NSRect(x: 298 + CGFloat(i) * 65, y: 512 - height / 2, width: 38, height: height), xRadius: 19, yRadius: 19)
        bar.fill()
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon render failed") }
    try data.write(to: directory.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
    try render(size: size, filename: "icon_\(size)x\(size).png")
    try render(size: size * 2, filename: "icon_\(size)x\(size)@2x.png")
}
