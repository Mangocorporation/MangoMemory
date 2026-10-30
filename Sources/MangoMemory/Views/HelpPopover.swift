import SwiftUI

/// The info button by the gear and its popover: one sentence per number (S-021).
struct HelpButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Button("What These Numbers Mean", systemImage: "info.circle") { model.showingHelp.toggle() }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Explain what each number means")
            .popover(isPresented: $model.showingHelp, arrowEdge: .bottom) {
                HelpPopover()
            }
    }
}

struct HelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Memory pressure shows how hard macOS works to find memory. Watch it, not Free.")
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Space.sm, verticalSpacing: Space.sm) {
                ForEach(MemoryPart.allCases) { part in
                    GridRow {
                        Text(part.title)
                            .fontWeight(.medium)
                        Text(part.explanation)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.callout)
                }
            }
        }
        .padding(Space.margin)
        .frame(width: 360)
    }
}

extension MemoryPart {
    /// One sentence in plain words, for tooltips and the help popover.
    var explanation: String {
        switch self {
        case .app: "Memory apps use right now. Quitting an app gives it back."
        case .wired: "Memory macOS keeps for itself. It can't be compressed or moved to disk."
        case .compressed: "Memory macOS squeezed to make room, which is faster than writing it to disk."
        case .fileCache: "Recently used files kept in memory so they open fast. macOS frees it as soon as apps need it."
        case .free: "Memory nothing uses. Low Free is normal: macOS puts spare memory to work as file cache."
        case .swap: "Memory written to disk because there wasn't enough. A lot of swap means pressure was high."
        case .total: "All the memory in this Mac."
        }
    }
}
