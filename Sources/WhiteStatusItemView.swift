import AppKit

final class WhiteStatusItemView: NSView {
    private let font: NSFont
    private let boltImage: NSImage?

    var title = "-- W" {
        didSet { needsDisplay = true }
    }

    init(font: NSFont) {
        self.font = font
        self.boltImage = Self.makeWhiteBoltImage()
        super.init(frame: .zero)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let the native NSStatusBarButton receive clicks and open its menu.
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let iconSize = NSSize(width: 14, height: 14)
        let iconRect = NSRect(
            x: 8,
            y: bounds.midY - iconSize.height / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let textRect = NSRect(
            x: iconRect.maxX + 5,
            y: bounds.midY - (font.ascender - font.descender) / 2,
            width: textWidth + 1,
            height: font.ascender - font.descender + 1
        )

        boltImage?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        (title as NSString).draw(
            in: textRect,
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.white
            ]
        )
    }

    private static func makeWhiteBoltImage() -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: "bolt.fill",
            accessibilityDescription: "BatteryWatt"
        ) else {
            return nil
        }

        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        symbol.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .destinationIn,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
