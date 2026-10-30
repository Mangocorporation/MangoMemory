import Foundation

/// The last hour of pressure, one sample per refresh, and the clears in it (S-020).
public struct PressureHistory: Sendable, Equatable {
    public struct Sample: Sendable, Equatable {
        public var date: Date
        public var percent: Int
        public var level: PressureLevel
    }

    /// One bar of the chart: the worst minute.
    public struct Minute: Sendable, Equatable, Identifiable {
        public var start: Date
        public var percent: Int
        public var level: PressureLevel
        public var id: Date { start }
    }

    public static let span: TimeInterval = 3600

    public private(set) var samples: [Sample] = []
    public private(set) var clears: [Date] = []

    public init() {}

    public mutating func append(_ stats: MemoryStats, at now: Date) {
        samples.append(Sample(date: now, percent: stats.pressurePercent, level: stats.level))
        trim(now)
    }

    public mutating func cleared(at now: Date) {
        clears.append(now)
        trim(now)
    }

    /// Drops what is older than an hour. Samples arrive in order, so the old ones are at the front.
    private mutating func trim(_ now: Date) {
        let oldest = now.addingTimeInterval(-Self.span)
        if let keep = samples.firstIndex(where: { $0.date >= oldest }) {
            samples.removeFirst(keep)
        } else {
            samples.removeAll()
        }
        clears.removeAll { $0 < oldest }
    }

    /// One entry per minute that has samples: the highest percent and the worst level in it.
    public func minutes() -> [Minute] {
        var result: [Minute] = []
        for sample in samples {
            let start = Date(timeIntervalSinceReferenceDate: (sample.date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
            if let last = result.last, last.start == start {
                result[result.count - 1].percent = max(last.percent, sample.percent)
                if sample.level.severity > last.level.severity { result[result.count - 1].level = sample.level }
            } else {
                result.append(Minute(start: start, percent: sample.percent, level: sample.level))
            }
        }
        return result
    }
}

extension PressureLevel {
    /// Normal 0, High 1, Critical 2.
    public var severity: Int {
        switch self {
        case .normal: 0
        case .high: 1
        case .critical: 2
        }
    }
}

/// "MangoCleaner: 0.2 % CPU · 28 MB" (S-022).
public enum SelfUsageText {
    public static func line(cpuPercent: Double, footprint: UInt64) -> String {
        "MangoCleaner: \(String(format: "%.1f", cpuPercent)) % CPU · \(ByteText.string(footprint))"
    }
}
