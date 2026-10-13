// Renders the app icon to an .icns: usage `swift scripts/make-icon.swift <out.icns>`
import AppKit

let out = CommandLine.arguments[1]
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // macOS icon grid: ~80% body with soft shadow.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset * 1.15, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSGradient(colors: [NSColor(red: 0.42, green: 0.88, blue: 1.0, alpha: 1),
                        NSColor(red: 0.14, green: 0.42, blue: 0.98, alpha: 1)])!.draw(in: path, angle: -60)
    NSShadow().set()
    // Glass highlight on the upper half.
    NSGraphicsContext.current!.saveGraphicsState()
    path.addClip()
    let hl = NSBezierPath(ovalIn: NSRect(x: rect.minX - rect.width * 0.2, y: rect.midY,
                                         width: rect.width * 1.4, height: rect.height * 0.9))
    NSColor.white.withAlphaComponent(0.16).setFill()
    hl.fill()
    NSGraphicsContext.current!.restoreGraphicsState()
    // Snowflake glyph.
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "snowflake", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        sym.draw(in: NSRect(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: tmp.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: tmp.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", tmp.path, "-o", out]
try! p.run(); p.waitUntilExit()
print("Wrote \(out)")
