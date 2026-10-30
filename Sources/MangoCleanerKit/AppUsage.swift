import Foundation

/// One running process: its footprint and the process responsible for it
/// (Safari for its web pages, Chrome for its renderers).
public struct ProcessSample: Sendable, Equatable {
    public var pid: Int32
    public var responsiblePID: Int32
    public var footprint: UInt64

    public init(pid: Int32, responsiblePID: Int32, footprint: UInt64) {
        self.pid = pid
        self.responsiblePID = responsiblePID
        self.footprint = footprint
    }
}

/// An app in Top Apps.
public struct AppUsage: Sendable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    public var bundlePath: String?
    public var bytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, bundlePath: String?, bytes: UInt64) {
        self.pid = pid
        self.name = name
        self.bundlePath = bundlePath
        self.bytes = bytes
    }
}

public enum AppUsageRanking {
    /// Adds each process's footprint to the app responsible for it, keeps
    /// only `apps` (minus `excluding`), and returns the `limit` biggest, largest first.
    public static func top(_ limit: Int, samples: [ProcessSample], apps: [AppUsage],
                           excluding: Int32) -> [AppUsage] {
        let wanted = Set(apps.map(\.pid)).subtracting([excluding])
        var totals: [Int32: UInt64] = [:]
        for sample in samples {
            let owner = wanted.contains(sample.responsiblePID) ? sample.responsiblePID : sample.pid
            guard wanted.contains(owner) else { continue }
            totals[owner, default: 0] += sample.footprint
        }
        return apps
            .filter { wanted.contains($0.pid) && totals[$0.pid] != nil }
            .map { app in
                var app = app
                app.bytes = totals[app.pid] ?? 0
                return app
            }
            .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.name < $1.name }
            .prefix(limit)
            .map { $0 }
    }
}
