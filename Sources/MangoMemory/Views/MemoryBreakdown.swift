import MangoMemoryKit
import SwiftUI

/// The parts of memory, in bar order. Swap and Total are rows without a segment.
enum MemoryPart: String, CaseIterable, Identifiable {
    case app, wired, compressed, fileCache, free, swap, total

    var id: String { rawValue }

    /// The parts that add up to total and get a bar segment.
    static let segments: [MemoryPart] = [.app, .wired, .compressed, .fileCache, .free]

    var title: String {
        switch self {
        case .app: "App memory"
        case .wired: "Wired"
        case .compressed: "Compressed"
        case .fileCache: "File cache"
        case .free: "Free"
        case .swap: "Swap"
        case .total: "Total"
        }
    }

    var color: Color? {
        switch self {
        case .app: StatusColor.appMemory
        case .wired: StatusColor.wired
        case .compressed: StatusColor.compressed
        case .fileCache: StatusColor.fileCache
        case .free: StatusColor.free
        case .swap, .total: nil
        }
    }

    func bytes(in stats: MemoryStats) -> UInt64 {
        switch self {
        case .app: stats.app
        case .wired: stats.wired
        case .compressed: stats.compressed
        case .fileCache: stats.fileCache
        case .free: stats.free
        case .swap: stats.swapUsed
        case .total: stats.total
        }
    }

    /// "None" for zero swap; sizes otherwise.
    func value(in stats: MemoryStats) -> String {
        self == .swap && stats.swapUsed == 0 ? "None" : ByteText.string(bytes(in: stats))
    }
}

/// The stacked bar and the details rows (S-004).
struct MemoryBreakdown: View {
    let stats: MemoryStats
    let history: PressureHistory

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            bar
            Grid(alignment: .leading, horizontalSpacing: Space.sm, verticalSpacing: Space.xs) {
                ForEach(MemoryPart.allCases) { part in
                    GridRow {
                        Circle()
                            .fill(part.color ?? .clear)
                            .frame(width: 8, height: 8)
                        Text(part.title)
                            .foregroundStyle(part.color == nil ? .secondary : .primary)
                        Text(part.value(in: stats))
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.callout)
                    .help(part.explanation)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(part.title), \(part.value(in: stats))")
                    .accessibilityHint(part.explanation)
                }
            }
            .animation(Motion.numberRoll, value: stats)
            PressureChart(history: history)
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(MemoryPart.segments) { part in
                    Rectangle()
                        .fill(part.color ?? .clear)
                        .frame(width: Self.width(of: part, in: stats, total: proxy.size.width))
                        .help("\(part.title) · \(ByteText.string(part.bytes(in: stats)))")
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
        .animation(Motion.bar, value: stats)
        .accessibilityHidden(true)
    }

    /// Proportional to the part's share of total; the gaps come out of the width.
    static func width(of part: MemoryPart, in stats: MemoryStats, total width: CGFloat) -> CGFloat {
        guard stats.total > 0 else { return 0 }
        let usable = max(0, width - CGFloat(MemoryPart.segments.count - 1))
        return usable * CGFloat(part.bytes(in: stats)) / CGFloat(stats.total)
    }
}
