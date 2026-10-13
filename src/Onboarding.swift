import AppKit

/// The first-launch window: what the app does, where it lives, and the two choices worth
/// making up front. Everything in it can be changed later from the menu.
final class Onboarding: NSObject, NSWindowDelegate {
    var onThorough: (Bool) -> Void = { _ in }
    /// Returns whether the login item is active afterwards, which the checkbox then reflects.
    var onLaunchAtLogin: (Bool) -> Bool = { $0 }
    var onClose: () -> Void = {}

    let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                          backing: .buffered, defer: true)

    private static let textWidth: CGFloat = 380
    private static let inset: CGFloat = 32

    init(icon: NSImage, hotkey: String, thorough: Bool, launchAtLogin: Bool) {
        super.init()

        let tile = NSImageView(image: icon)
        tile.imageScaling = .scaleProportionallyUpOrDown
        tile.widthAnchor.constraint(equalToConstant: 88).isActive = true
        tile.heightAnchor.constraint(equalToConstant: 88).isActive = true

        let title = Self.label(L("onboarding.title"), font: .systemFont(ofSize: 22, weight: .bold))
        let subtitle = Self.label(L("onboarding.subtitle"), font: .systemFont(ofSize: 13), color: .secondaryLabelColor)
        title.alignment = .center
        subtitle.alignment = .center
        let header = Self.stack([tile, title, subtitle], alignment: .centerX, spacing: 8)
        header.setCustomSpacing(10, after: tile)

        let steps = Self.stack([
            Self.step("keyboard", L("onboarding.shortcut.title", hotkey), L("onboarding.shortcut.text")),
            Self.step("menubar.rectangle", L("onboarding.menu.title"), L("onboarding.menu.text")),
            Self.step("checkmark.shield", L("onboarding.safe.title"), L("onboarding.safe.text")),
        ], alignment: .leading, spacing: 14)

        let thoroughBox = NSButton(checkboxWithTitle: L("onboarding.thorough"), target: self,
                                   action: #selector(thoroughChanged))
        thoroughBox.state = thorough ? .on : .off
        let thoroughNote = Self.label(L("option.thorough.note"), font: .systemFont(ofSize: 11),
                                      color: .secondaryLabelColor, width: Self.textWidth - 20)
        let loginBox = NSButton(checkboxWithTitle: L("onboarding.login"), target: self,
                                action: #selector(loginChanged))
        loginBox.state = launchAtLogin ? .on : .off
        let options = Self.stack([thoroughBox, Self.indented(thoroughNote, by: 20), loginBox],
                                 alignment: .leading, spacing: 4)
        options.setCustomSpacing(12, after: options.views[1])

        let done = NSButton(title: L("onboarding.done"), target: window, action: #selector(NSWindow.close))
        done.keyEquivalent = "\r"
        done.controlSize = .large

        let separator = NSBox()
        separator.boxType = .separator

        let content = Self.stack([header, steps, separator, options, done], alignment: .leading, spacing: 22)
        // The title bar is transparent, so the top inset also has to clear the close button.
        content.edgeInsets = NSEdgeInsets(top: 44, left: Self.inset, bottom: 24, right: Self.inset)
        content.widthAnchor.constraint(equalToConstant: Self.textWidth + 2 * Self.inset).isActive = true
        for fullWidth in [header, separator, done] {
            fullWidth.widthAnchor.constraint(equalToConstant: Self.textWidth).isActive = true
        }
        content.setCustomSpacing(18, after: options)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    @objc private func thoroughChanged(_ sender: NSButton) {
        onThorough(sender.state == .on)
    }

    @objc private func loginChanged(_ sender: NSButton) {
        sender.state = onLaunchAtLogin(sender.state == .on) ? .on : .off
    }

    // MARK: - Building blocks

    private static func step(_ symbolName: String, _ title: String, _ text: String) -> NSView {
        let icon = NSImageView(image: symbol(symbolName, pointSize: 17, weight: .regular))
        icon.contentTintColor = .controlAccentColor
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
        let width = textWidth - 30 - 12
        let texts = stack([label(title, font: .systemFont(ofSize: 13, weight: .semibold), width: width),
                           label(text, font: .systemFont(ofSize: 12), color: .secondaryLabelColor, width: width)],
                          alignment: .leading, spacing: 2)
        let row = NSStackView(views: [icon, texts])
        row.alignment = .top
        row.spacing = 12
        return row
    }

    private static func label(_ text: String, font: NSFont, color: NSColor = .labelColor,
                              width: CGFloat = textWidth) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isSelectable = false
        label.preferredMaxLayoutWidth = width
        return label
    }

    private static func stack(_ views: [NSView], alignment: NSLayoutConstraint.Attribute, spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = alignment
        stack.spacing = spacing
        return stack
    }

    private static func indented(_ view: NSView, by indent: CGFloat) -> NSView {
        let row = NSStackView(views: [view])
        row.edgeInsets = NSEdgeInsets(top: 0, left: indent, bottom: 0, right: 0)
        return row
    }

    private static func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        return image.withSymbolConfiguration(.init(pointSize: pointSize, weight: weight)) ?? image
    }
}
