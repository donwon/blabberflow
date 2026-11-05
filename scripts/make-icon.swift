import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor(calibratedRed: 0.40, green: 0.32, blue: 0.66, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88), xRadius: p * 0.20, yRadius: p * 0.20).fill()
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.99, alpha: 1).setStroke()
        let heights: [CGFloat] = [0.16, 0.34, 0.52, 0.38, 0.20]
        for (i, height) in heights.enumerated() {
            let path = NSBezierPath(); path.lineCapStyle = .round; path.lineWidth = p * 0.055
            let x = p * (0.30 + CGFloat(i) * 0.10)
            path.move(to: NSPoint(x: x, y: p * (0.5 - height / 2)))
            path.line(to: NSPoint(x: x, y: p * (0.5 + height / 2))); path.stroke()
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not render icon") }
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
