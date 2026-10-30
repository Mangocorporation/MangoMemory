import AppKit
import MangoCleanerKit
import SwiftUI

/// The menu bar item: a memory glyph and the available memory (S-002).
/// It is drawn at launch, so it also starts the self-test and snapshot runs,
/// which need SwiftUI's openSettings.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let stats = model.monitor.stats
        HStack(spacing: Space.xs) {
            Image(nsImage: Self.glyph(for: stats?.level))
            if let stats {
                Text(ByteText.string(stats.available))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(stats))
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

    static func spoken(_ stats: MemoryStats?) -> String {
        guard let stats else { return "MangoCleaner, reading memory" }
        return "MangoCleaner, memory pressure \(stats.level.title), \(ByteText.string(stats.available)) available"
    }
}
