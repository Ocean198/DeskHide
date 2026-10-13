// Renders the Mac App Store screenshots (2880 × 1800, no alpha) without touching the real
// screen: a drawn desktop, the app's real onboarding view and a redrawn copy of its menu.
// Usage: make-screenshots <assets directory> <compiled .lproj to take the app's texts from>
import AppKit
import UniformTypeIdentifiers

private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
private let canvas = CGSize(width: 2880, height: 1800)
private var screen = CGSize(width: 1440, height: 900)  // the mock display of the current page, in points
private let menuBarHeight: CGFloat = 30

private func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

@main
struct MakeScreenshots {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .aqua)
        let assets = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets")
        let output = assets.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let appIcon = NSImage(contentsOf: assets.appendingPathComponent("AppIcon-1024.png")) ?? NSImage()
        // The headlines below are English only; everything shown inside the app comes from the
        // string catalog, so menu and onboarding always match what the app really says.
        if CommandLine.arguments.count > 2, let strings = Bundle(path: CommandLine.arguments[2]) {
            localizationBundle = strings
        }

        try render(to: output.appendingPathComponent("1-before-after.png"),
                   title: "A clean desktop at a keystroke.",
                   subtitle: "DeskHide hides every icon on your desktop – and brings them back just as fast.",
                   pointScale: 2240 / screen.width, viewport: .zero) { ctx in
            wallpaper()
            desktopIcons(count: 30, in: CGRect(x: 0, y: 0, width: screen.width / 2 - 24, height: screen.height),
                         avoiding: comparisonDivider(draw: false))
            menuBar(hidden: true)
            comparisonDivider()
        }

        try render(to: output.appendingPathComponent("2-menu.png"),
                   title: "Everything lives in the menu bar.",
                   subtitle: "Hide widgets as well, change the shortcut, launch at login.",
                   pointScale: 2.6, viewport: CGPoint(x: screen.width - 2240 / 2.6, y: 0)) { _ in
            wallpaper()
            documentWindow(CGRect(x: 610, y: 270, width: 440, height: 330))
            menuBar(hidden: true, highlighted: true)
            appMenu()
        }

        try render(to: output.appendingPathComponent("3-introduction.png"),
                   title: "Ready in seconds.",
                   subtitle: "A short introduction, two options – done.",
                   display: CGSize(width: 1120, height: 700), pointScale: 2, viewport: .zero) { _ in
            // A smaller display at twice the size keeps the window's text readable in the store.
            let center = CGPoint(x: screen.width / 2, y: menuBarHeight + 325)
            wallpaper()
            desktopIcons(count: 18, in: CGRect(origin: .zero, size: screen),
                         avoiding: [onboardingWindow(icon: appIcon, center: center, draw: false).insetBy(dx: -16, dy: -16)])
            menuBar(hidden: false)
            onboardingWindow(icon: appIcon, center: center)
        }
    }

    // MARK: - Page

    /// One screenshot: headline on top, below it a card that looks into the mock display.
    /// `scene` draws in display points; `viewport` is the display point at the card's corner.
    static func render(to url: URL, title: String, subtitle: String, display: CGSize = CGSize(width: 1440, height: 900),
                       pointScale: CGFloat, viewport: CGPoint, scene: (CGContext) -> Void) throws {
        screen = display
        let ctx = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.translateBy(x: 0, y: canvas.height)
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

        linearGradient([color(0x0E1432), color(0x1B2670)], from: .zero, to: CGPoint(x: 0, y: canvas.height))
        radialGlow(color(0x4C7DFF, 0.55), center: CGPoint(x: canvas.width / 2, y: 120), radius: 1500)
        text(title, font: .systemFont(ofSize: 112, weight: .bold), color: .white, kern: -2,
             in: CGRect(x: 0, y: 104, width: canvas.width, height: 150), alignment: .center)
        text(subtitle, font: .systemFont(ofSize: 48, weight: .regular), color: color(0xFFFFFF, 0.74),
             in: CGRect(x: 0, y: 262, width: canvas.width, height: 70), alignment: .center)

        // The card runs off the bottom edge, which crops a strip of the display.
        let card = CGRect(x: 320, y: 440, width: 2240, height: 1500)
        let shape = CGPath(roundedRect: card, cornerWidth: 44, cornerHeight: 44, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -36), blur: 110, color: color(0x000000, 0.55).cgColor)
        ctx.addPath(shape)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        ctx.translateBy(x: card.minX, y: card.minY)
        ctx.scaleBy(x: pointScale, y: pointScale)
        ctx.translateBy(x: -viewport.x, y: -viewport.y)
        scene(ctx)
        ctx.restoreGState()

        ctx.addPath(shape)
        ctx.setStrokeColor(color(0xFFFFFF, 0.22).cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()

        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        print(url.lastPathComponent, rep.pixelsWide, "x", rep.pixelsHigh)
    }

    // MARK: - Mock display

    // Drawn rather than borrowed: Apple's wallpapers are not ours to ship in marketing material.
    static func wallpaper() {
        let full = CGRect(origin: .zero, size: screen)
        linearGradient([color(0x25347F), color(0x5B4AA8), color(0xD9768C), color(0xF7B77A)],
                       from: CGPoint(x: 200, y: 0), to: CGPoint(x: full.maxX - 200, y: full.maxY))
        radialGlow(color(0x38D0C6, 0.50), center: CGPoint(x: 1240, y: 120), radius: 620)
        radialGlow(color(0xC054D8, 0.40), center: CGPoint(x: 260, y: 420), radius: 560)
        radialGlow(color(0xFFD08A, 0.45), center: CGPoint(x: 1000, y: 900), radius: 620)
    }

    static func menuBar(hidden: Bool, highlighted: Bool = false) {
        color(0xFFFFFF, 0.22).setFill()
        CGRect(x: 0, y: 0, width: screen.width, height: menuBarHeight).fill()

        var x: CGFloat = 20
        for (index, title) in ["\u{F8FF}", "Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
            let font = NSFont.systemFont(ofSize: index == 0 ? 16 : 13.5, weight: index == 1 ? .bold : .medium)
            x += text(title, font: font, color: .white, in: CGRect(x: x, y: index == 0 ? 5 : 6.5, width: 200, height: 20)) + 20
        }

        var right = screen.width - 18
        right -= 132
        text("Tue Oct 13  9:41 AM", font: .systemFont(ofSize: 13.5, weight: .medium), color: .white,
             in: CGRect(x: right, y: 6.5, width: 132, height: 20), alignment: .right)
        for name in ["switch.2", "magnifyingglass", "wifi", "battery.75percent"] {
            right -= 34
            symbol(name, pointSize: 14, color: .white, centeredIn: CGRect(x: right, y: 0, width: 30, height: menuBarHeight))
        }
        right -= 38
        let item = CGRect(x: right, y: 3, width: 34, height: menuBarHeight - 6)
        if highlighted {
            color(0xFFFFFF, 0.30).setFill()
            NSBezierPath(roundedRect: item, xRadius: 6, yRadius: 6).fill()
        }
        symbol(hidden ? "eye.slash" : "eye", pointSize: 14, color: .white, centeredIn: item)
    }

    /// A messy desktop: `count` icons spread over the grid cells inside `area`, leaving out
    /// cells that touch one of the `avoiding` rects. A fixed seed gives the same picture every run.
    static func desktopIcons(count: Int, in area: CGRect, avoiding: [CGRect] = []) {
        // Only types that keep Apple's generic icon. PDF, for one, shows the artwork of
        // whichever app has claimed it – on this Mac that would be Adobe's.
        let items: [(UTType, String)] = [
            (.folder, "Projects"), (.png, "Screenshot 2026-10-12.png"), (.plainText, "Notes.txt"),
            (.folder, "Clients"), (.jpeg, "Moodboard.jpg"), (.zip, "Archive.zip"), (.rtf, "Briefing.rtf"),
            (.folder, "Export"), (.png, "Logo_v3.png"), (.mpeg4Movie, "Teaser.mp4"), (.commaSeparatedText, "Hours.csv"),
            (.folder, "Old"), (.jpeg, "IMG_2041.jpg"), (.png, "Icon-Draft.png"), (.plainText, "Todo.txt"),
            (.folder, "Photos"), (.rtf, "Quote.rtf"), (.png, "Header_final.png"), (.jpeg, "Team.jpg"),
            (.zip, "Fonts.zip"), (.folder, "Invoices"), (.png, "Screenshot 2026-10-09.png"),
            (.commaSeparatedText, "Export.csv"), (.jpeg, "IMG_2042.jpg"), (.folder, "Templates"),
            (.plainText, "Ideas.txt"), (.png, "Mockup_A.png"), (.mpeg4Movie, "Demo.mp4"),
            (.folder, "Misc"), (.png, "Mockup_B.png"), (.rtf, "Contract.rtf"), (.jpeg, "Sketch.jpg"),
            (.folder, "Private"), (.zip, "Backup.zip"), (.png, "Favicon.png"), (.plainText, "Changelog.txt"),
        ]
        let cell = CGSize(width: 104, height: 102)
        var cells: [CGRect] = []
        for column in 0..<13 {
            for row in 0..<8 {
                let frame = CGRect(x: screen.width - 22 - cell.width * CGFloat(column + 1),
                                   y: menuBarHeight + 14 + cell.height * CGFloat(row), width: cell.width, height: cell.height)
                if area.contains(frame), !avoiding.contains(where: frame.intersects) { cells.append(frame) }
            }
        }
        var seed: UInt64 = 20261013
        func next(below bound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int(seed >> 33) % bound
        }
        for index in cells.indices.dropLast() {
            cells.swapAt(index, index + next(below: cells.count - index))
        }

        let shadow = NSShadow()
        shadow.shadowColor = color(0x000000, 0.7)
        shadow.shadowBlurRadius = 2.5
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        for (frame, (type, name)) in zip(cells.prefix(count), items) {
            NSWorkspace.shared.icon(for: type).draw(in: CGRect(x: frame.minX + 20, y: frame.minY, width: 64, height: 64),
                                                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                                                    hints: [.interpolation: NSImageInterpolation.high.rawValue])
            text(name, font: .systemFont(ofSize: 12, weight: .semibold), color: .white,
                 in: CGRect(x: frame.minX + 2, y: frame.minY + 67, width: cell.width - 4, height: 32), alignment: .center,
                 shadow: shadow, lineBreak: .byTruncatingMiddle)
        }
    }

    /// The slider handle between "before" and "after", carrying the shortcut that does the trick.
    /// Returns the areas it covers; with `draw` off it only measures, so icons can keep clear.
    @discardableResult
    static func comparisonDivider(draw: Bool = true) -> [CGRect] {
        let x = screen.width / 2
        let labels = [("Before", CGRect(x: x - 22 - 84, y: menuBarHeight + 22, width: 84, height: 32)),
                      ("After", CGRect(x: x + 22, y: menuBarHeight + 22, width: 74, height: 32))]
        let keys = ["⌃", "⌥", "⌘", "D"]
        let keySize = CGSize(width: 46, height: 44), gap: CGFloat = 8, padding: CGFloat = 14
        let width = CGFloat(keys.count) * keySize.width + CGFloat(keys.count - 1) * gap + 2 * padding
        let handle = CGRect(x: x - width / 2, y: 420, width: width, height: keySize.height + 2 * padding)
        let covered = (labels.map(\.1) + [handle]).map { $0.insetBy(dx: -14, dy: -14) }
        guard draw else { return covered }

        color(0xFFFFFF, 0.95).setFill()
        CGRect(x: x - 1.5, y: menuBarHeight, width: 3, height: screen.height).fill()
        for (label, pill) in labels {
            color(0x000000, 0.42).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 16, yRadius: 16).fill()
            text(label, font: .systemFont(ofSize: 15, weight: .semibold), color: .white,
                 in: pill.offsetBy(dx: 0, dy: 6), alignment: .center)
        }
        shadowed(blur: 30, offset: 10, alpha: 0.40) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: handle, xRadius: 22, yRadius: 22).fill()
        }
        for (index, key) in keys.enumerated() {
            let cap = CGRect(x: handle.minX + padding + CGFloat(index) * (keySize.width + gap), y: handle.minY + padding,
                             width: keySize.width, height: keySize.height)
            color(0xEEF0F5).setFill()
            NSBezierPath(roundedRect: cap, xRadius: 10, yRadius: 10).fill()
            color(0xC9CDD8).setStroke()
            NSBezierPath(roundedRect: cap.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()
            text(key, font: .systemFont(ofSize: 22, weight: .semibold), color: color(0x1D2233),
                 in: cap.offsetBy(dx: 0, dy: 8), alignment: .center)
        }
        return covered
    }

    /// A neutral document window, so the cleared desktop has something to sit behind.
    static func documentWindow(_ frame: CGRect) {
        window(frame) {
            color(0xF4F5F8).setFill()
            CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 44).fill()
            color(0xE3E5EB).setFill()
            CGRect(x: frame.minX, y: frame.minY + 44, width: frame.width, height: 1).fill()
            text("Draft", font: .systemFont(ofSize: 13, weight: .semibold), color: color(0x3A3F4D),
                 in: CGRect(x: frame.minX, y: frame.minY + 14, width: frame.width, height: 18), alignment: .center)

            let picture = CGRect(x: frame.minX + 28, y: frame.minY + 72, width: frame.width - 56, height: 150)
            NSGraphicsContext.current?.cgContext.saveGState()
            NSBezierPath(roundedRect: picture, xRadius: 10, yRadius: 10).addClip()
            linearGradient([color(0x8FB8FF), color(0xC9A7F5), color(0xFFC2A8)],
                           from: CGPoint(x: picture.minX, y: picture.minY), to: CGPoint(x: picture.maxX, y: picture.maxY))
            NSGraphicsContext.current?.cgContext.restoreGState()
            for (line, width) in [0.62, 0.86, 0.74].enumerated() {
                color(line == 0 ? 0xC4C8D4 : 0xE1E4EB).setFill()
                let bar = CGRect(x: picture.minX, y: picture.maxY + 24 + CGFloat(line) * 22,
                                 width: picture.width * width, height: line == 0 ? 12 : 9)
                NSBezierPath(roundedRect: bar, xRadius: 4.5, yRadius: 4.5).fill()
            }
        }
        trafficLights(at: CGPoint(x: frame.minX + 18, y: frame.minY + 16), closeOnly: false)
    }

    /// The app's menu, redrawn item for item – an open NSMenu cannot be rendered off screen.
    static func appMenu() {
        let rows: [(title: String?, checked: Bool, shortcut: String)] = [
            (L("menu.show"), false, "⌃⌥⌘D"), (nil, false, ""),
            (L("menu.widgets"), true, ""), (L("menu.thorough"), true, ""),
            (L("menu.shortcut"), false, ""), (L("menu.login"), true, ""), (nil, false, ""),
            (L("menu.introduction"), false, ""), (L("menu.quit"), false, "⌘Q"),
        ]
        let rowHeight: CGFloat = 25, separatorHeight: CGFloat = 11, padding: CGFloat = 6, width: CGFloat = 348
        let height = rows.reduce(2 * padding) { $0 + ($1.title == nil ? separatorHeight : rowHeight) }
        let frame = CGRect(x: screen.width - 10 - width, y: menuBarHeight + 5, width: width, height: height)
        shadowed(blur: 34, offset: 12, alpha: 0.38) {
            color(0xF6F6F8, 0.97).setFill()
            NSBezierPath(roundedRect: frame, xRadius: 11, yRadius: 11).fill()
        }
        color(0x000000, 0.14).setStroke()
        NSBezierPath(roundedRect: frame.insetBy(dx: 0.25, dy: 0.25), xRadius: 11, yRadius: 11).stroke()

        var y = frame.minY + padding
        for (index, row) in rows.enumerated() {
            guard let title = row.title else {
                color(0x000000, 0.12).setFill()
                CGRect(x: frame.minX + 14, y: y + separatorHeight / 2 - 0.5, width: width - 28, height: 1).fill()
                y += separatorHeight
                continue
            }
            let selected = index == 0
            if selected {
                color(0x2F6BF3).setFill()
                NSBezierPath(roundedRect: CGRect(x: frame.minX + padding, y: y, width: width - 2 * padding, height: rowHeight),
                             xRadius: 6, yRadius: 6).fill()
            }
            let ink = selected ? NSColor.white : color(0x1C1C1E)
            if row.checked {
                symbol("checkmark", pointSize: 11, weight: .bold, color: ink,
                       centeredIn: CGRect(x: frame.minX + 10, y: y, width: 22, height: rowHeight))
            }
            text(title, font: .systemFont(ofSize: 13.5), color: ink,
                 in: CGRect(x: frame.minX + 34, y: y + 4, width: width - 50, height: 18))
            text(row.shortcut, font: .systemFont(ofSize: 13.5), color: selected ? .white : color(0x1C1C1E, 0.45),
                 in: CGRect(x: frame.minX, y: y + 4, width: width - 18, height: 18), alignment: .right)
            y += rowHeight
        }
    }

    /// The real onboarding view, rendered by AppKit, inside a drawn window frame.
    /// Returns the window's frame; with `draw` off it only measures.
    @discardableResult
    static func onboardingWindow(icon: NSImage, center: CGPoint, draw: Bool = true) -> CGRect {
        let onboarding = Onboarding(icon: icon, hotkey: "⌃⌥⌘D", thorough: true, launchAtLogin: true)
        guard let view = onboarding.window.contentView else { return .zero }
        // Off screen nothing is ever the key window, and controls would draw greyed out. Users
        // only see this window while it is key, so it is rendered in one that claims to be.
        let host = KeyWindow(contentRect: view.bounds, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)
        host.contentView = view
        view.layoutSubtreeIfNeeded()
        let frame = CGRect(x: center.x - view.bounds.width / 2, y: center.y - view.bounds.height / 2,
                           width: view.bounds.width, height: view.bounds.height)
        guard draw, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return frame }
        view.cacheDisplay(in: view.bounds, to: rep)

        window(frame) {
            color(0xECECEC).setFill()
            frame.fill()
            rep.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        trafficLights(at: CGPoint(x: frame.minX + 18, y: frame.minY + 18), closeOnly: true)
        return frame
    }

    static func window(_ frame: CGRect, radius: CGFloat = 14, content: () -> Void) {
        let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        shadowed(blur: 50, offset: 22, alpha: 0.45) {
            NSColor.white.setFill()
            shape.fill()
        }
        NSGraphicsContext.current?.cgContext.saveGState()
        shape.addClip()
        content()
        NSGraphicsContext.current?.cgContext.restoreGState()
        color(0x000000, 0.18).setStroke()
        NSBezierPath(roundedRect: frame.insetBy(dx: 0.25, dy: 0.25), xRadius: radius, yRadius: radius).stroke()
    }

    static func trafficLights(at origin: CGPoint, closeOnly: Bool) {
        let colors: [UInt32] = closeOnly ? [0xFF5F57, 0xD4D4D8, 0xD4D4D8] : [0xFF5F57, 0xFEBC2E, 0x28C840]
        for (index, hex) in colors.enumerated() {
            color(hex).setFill()
            NSBezierPath(ovalIn: CGRect(x: origin.x + CGFloat(index) * 20, y: origin.y, width: 12, height: 12)).fill()
        }
    }

    // MARK: - Drawing helpers

    /// Draws `string` and returns its width, so callers can lay out the next piece of text.
    @discardableResult
    static func text(_ string: String, font: NSFont, color: NSColor, kern: CGFloat = 0, in rect: CGRect,
                     alignment: NSTextAlignment = .left, shadow: NSShadow? = nil,
                     lineBreak: NSLineBreakMode = .byWordWrapping) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreak
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern,
                                                         .paragraphStyle: paragraph]
        attributes[.shadow] = shadow
        let attributed = NSAttributedString(string: string, attributes: attributes)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        return ceil(attributed.size().width)
    }

    static func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .medium, color: NSColor,
                       centeredIn rect: CGRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(.init(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let target = CGRect(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2,
                            width: image.size.width, height: image.size.height)
        image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    static func linearGradient(_ colors: [NSColor], from start: CGPoint, to end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: sRGB, colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        NSGraphicsContext.current?.cgContext.drawLinearGradient(gradient, start: start, end: end,
                                                                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radialGlow(_ color: NSColor, center: CGPoint, radius: CGFloat) {
        let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: sRGB, colors: colors, locations: nil) else { return }
        NSGraphicsContext.current?.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                                endCenter: center, endRadius: radius, options: [])
    }

    /// Shadows ignore the current transform, so they are scaled by hand to stay in display points.
    static func shadowed(blur: CGFloat, offset: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scale = abs(ctx.ctm.a)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -offset * scale), blur: blur * scale,
                      color: color(0x000000, alpha).cgColor)
        draw()
        ctx.restoreGState()
    }
}

/// Claims to be the key window of an active app. The underscored selectors are what AppKit's
/// controls actually ask; they are private, which is acceptable here because this script only
/// draws marketing images and is not part of the app.
private final class KeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    @objc(hasKeyAppearance) func claimsKeyAppearance() -> Bool { true }
    @objc(_hasKeyAppearance) func claimsPrivateKeyAppearance() -> Bool { true }
    @objc(_hasActiveAppearance) func claimsActiveAppearance() -> Bool { true }
    @objc(_hasActiveControls) func claimsActiveControls() -> Bool { true }
}
