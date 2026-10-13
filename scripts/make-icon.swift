// Draws the DeskHide app icon and exports every size macOS and the Mac App Store ask for.
// Usage: make-icon <assets directory>
//
// The glyph is drawn by hand on purpose: SF Symbols must not be used in app icons.
import AppKit
import SwiftUI

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                           CGFloat(hex & 0xFF) / 255, alpha])!
}

/// The icon at `size` pixels, drawn in the units of Apple's macOS grid: an 824 pt tile with
/// continuous corners, centred on a 1024 pt canvas.
func icon(size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(size) / 1024  // shadows are measured in pixels, everything else in grid units
    ctx.scaleBy(x: k, y: k)

    // Small sizes drop the background detail and get a heavier glyph, or they turn to mush.
    let detailed = size >= 128
    let stroke: CGFloat = size >= 128 ? 50 : size >= 64 ? 58 : 68
    let glyphScale: CGFloat = size >= 128 ? 1 : 1.12

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = RoundedRectangle(cornerRadius: 185.4, style: .continuous).path(in: tile).cgPath

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 22 * k, color: color(0x000000, 0.32))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x3355E8))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let body = CGGradient(colorsSpace: sRGB, colors: [color(0x5BA4FF), color(0x3F6BF2), color(0x3A3CCB)] as CFArray,
                          locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(body, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
    let glow = CGGradient(colorsSpace: sRGB, colors: [color(0xFFFFFF, 0.26), color(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 360, y: 900), startRadius: 0,
                           endCenter: CGPoint(x: 360, y: 900), endRadius: 640, options: [])

    if detailed {
        // The desktop's icons as ghosts: still there, just no longer in the picture.
        let cell: CGFloat = 168, gap: CGFloat = 60
        let origin = 512 - (3 * cell + 2 * gap) / 2
        for row in 0..<3 {
            for column in 0..<3 {
                let rect = CGRect(x: origin + CGFloat(column) * (cell + gap), y: origin + CGFloat(row) * (cell + gap),
                                  width: cell, height: cell)
                ctx.addPath(RoundedRectangle(cornerRadius: 40, style: .continuous).path(in: rect).cgPath)
            }
        }
        ctx.setFillColor(color(0xFFFFFF, 0.13))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // The crossed-out eye. It is drawn into its own layer so that the gap around the slash
    // can be erased from the eye without punching through the tile.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: glyphScale, y: glyphScale)
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * k), blur: 26 * k, color: color(0x10167A, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // Cubic lids with the control points pulled outwards: rounded shoulders make it read as an
    // eye, where a plain parabola comes out as two angle brackets once the slash cuts it.
    ctx.move(to: CGPoint(x: -292, y: 0))
    ctx.addCurve(to: CGPoint(x: 292, y: 0), control1: CGPoint(x: -168, y: 236), control2: CGPoint(x: 168, y: 236))
    ctx.addCurve(to: CGPoint(x: -292, y: 0), control1: CGPoint(x: 168, y: -236), control2: CGPoint(x: -168, y: -236))
    ctx.closePath()
    ctx.strokePath()
    ctx.fillEllipse(in: CGRect(x: -98, y: -98, width: 196, height: 196))

    let from = CGPoint(x: -206, y: 236), to = CGPoint(x: 206, y: -236)
    ctx.setBlendMode(.clear)
    ctx.setLineWidth(stroke + 56)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.strokePath()
    ctx.setBlendMode(.normal)
    ctx.setLineWidth(stroke)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.strokePath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // A hairline of light along the edge keeps the tile from looking flat on dark backgrounds.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.addPath(shape)
    ctx.setStrokeColor(color(0xFFFFFF, 0.22))
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("DeskHide-\(getpid()).iconset")
let appiconset = assets.appendingPathComponent("AppIcon.appiconset")
for directory in [iconset, appiconset] {
    try? FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

// macOS wants each point size at 1x and 2x; the 512 pt @2x one is the 1024 px App Store icon.
var entries: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let image = icon(size: points * scale)
        try write(image, to: iconset.appendingPathComponent(name))
        try write(image, to: appiconset.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: appiconset.appendingPathComponent("Contents.json"))
try write(icon(size: 1024), to: assets.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
