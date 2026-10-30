import Charts
import MangoMemoryKit
import SwiftUI

/// Pressure over the last hour, one bar per minute in its level's color,
/// with a mark at each clear (S-020).
struct PressureChart: View {
    let history: PressureHistory

    var body: some View {
        let minutes = history.minutes()
        let now = history.samples.last?.date ?? .now
        VStack(alignment: .leading, spacing: Space.xs) {
            Chart {
                ForEach(minutes) { minute in
                    BarMark(x: .value("Minute", minute.start, unit: .minute),
                            y: .value("Pressure", minute.percent))
                        .foregroundStyle(PressureHeader.color(minute.level))
                }
                ForEach(history.clears, id: \.self) { date in
                    RuleMark(x: .value("Cleared", date))
                        .foregroundStyle(Palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
            .chartXScale(domain: now.addingTimeInterval(-PressureHistory.span)...now)
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 40)
            HStack {
                Text("1 hour ago")
                Spacer()
                Text("Now")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(minutes: minutes, clears: history.clears.count))
        .help("Memory pressure over the last hour. Dashed lines mark each Clear File Cache.")
    }

    /// "Pressure over the last hour: highest 69 %, 1 clear."
    static func summary(minutes: [PressureHistory.Minute], clears: Int) -> String {
        guard let highest = minutes.map(\.percent).max() else { return "No pressure history yet." }
        return "Pressure over the last hour: highest \(highest) %, \(clears) \(clears == 1 ? "clear" : "clears")."
    }
}
