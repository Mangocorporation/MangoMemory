import AppKit
import MangoMemoryKit
import SwiftUI

/// The menu bar item: a memory glyph and the available memory (S-002).
/// It is drawn at launch, so it also starts the self-test and snapshot runs,
/// which need SwiftUI's openSettings.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        let stats = model.monitor.stats
        // The menu bar shows one image and ignores SwiftUI fonts: draw glyph and text together.
        Image(nsImage: Self.image(level: stats?.level, text: model.menuBarText.text(for: stats),
                                  large: model.largeMenuBarText))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(stats))
        // The label lives as long as the app, so it opens and closes the pinned window.
        .onChange(of: model.pinned) { _, pinned in
            pinned ? openWindow(id: PinnedWindow.id) : dismissWindow(id: PinnedWindow.id)
        }
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    /// Normal: the plain template glyph, like other menu bar items.
    /// High: yellow outline. Critical: filled red, so it differs by shape too.
    /// No reading yet: the plain glyph without text.
    static func glyph(for level: PressureLevel?) -> NSImage {
        let name: String
        let color: NSColor?
        switch level {
        case nil, .normal?: (name, color) = ("memorychip", nil)
        case .high?: (name, color) = ("memorychip", .systemYellow)
        case .critical?: (name, color) = ("memorychip.fill", .systemRed)
        }
        let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        var config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let color { config = config.applying(.init(paletteColors: [color])) }
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = color == nil
        return image
    }

    /// The glyph and the text in one image. At Normal it is a template, which
    /// macOS tints for a light or dark menu bar. At High and Critical the glyph
    /// keeps its color and the text uses the label color, drawn when shown.
    static func image(level: PressureLevel?, text: String?, large: Bool) -> NSImage {
        let glyph = glyph(for: level)
        guard let text else { return glyph }
        let template = glyph.isTemplate
        let font = NSFont.monospacedDigitSystemFont(ofSize: large ? 15 : 13, weight: .regular)
        let string = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: template ? NSColor.black : NSColor.labelColor,
        ])
        let textSize = string.size()
        let gap: CGFloat = Space.xs
        let height = max(glyph.size.height, ceil(textSize.height))
        let size = NSSize(width: ceil(glyph.size.width + gap + textSize.width), height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            glyph.draw(in: NSRect(x: 0, y: (height - glyph.size.height) / 2,
                                  width: glyph.size.width, height: glyph.size.height))
            string.draw(at: NSPoint(x: glyph.size.width + gap, y: (height - textSize.height) / 2))
            return true
        }
        image.isTemplate = template
        return image
    }

    static func spoken(_ stats: MemoryStats?) -> String {
        guard let stats else { return "MangoMemory, reading memory" }
        return "MangoMemory, memory pressure \(stats.level.title), \(ByteText.string(stats.available)) available"
    }
}
