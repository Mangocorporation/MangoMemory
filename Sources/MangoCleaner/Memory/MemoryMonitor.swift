import AppKit
import MangoCleanerKit

/// Where numbers come from: the kernel, or fixed sample numbers for snapshots and the self-test.
nonisolated protocol MemorySource: Sendable {
    func stats() -> MemoryStats?
    func topApps(_ limit: Int, apps: [AppUsage], excluding: Int32) -> [AppUsage]
}

nonisolated struct SystemMemorySource: MemorySource {
    func stats() -> MemoryStats? { SystemMemory.stats() }

    func topApps(_ limit: Int, apps: [AppUsage], excluding: Int32) -> [AppUsage] {
        AppUsageRanking.top(limit, samples: SystemMemory.processes(), apps: apps, excluding: excluding)
    }
}

/// Live memory numbers and Top Apps, refreshed every refresh interval off the main thread.
@Observable
final class MemoryMonitor {
    static let refreshChoices: [Int] = [1, 2, 5, 10]

    /// What the menu bar item shows. Changes every refresh.
    private(set) var stats: MemoryStats?
    /// What the memory window shows. Changes only while it is open, so a closed
    /// window never redraws or animates (that cost 23 % CPU, docs/FIXLOG.md).
    private(set) var windowStats: MemoryStats?
    private(set) var topApps: [AppUsage] = []
    /// Seconds between readings (Settings > General). Saved in Store.defaults.
    var refreshInterval: Int {
        didSet {
            Store.defaults.set(refreshInterval, forKey: "refreshInterval")
            restart()
        }
    }

    /// True while the memory window is open. Top Apps is read only then:
    /// the menu bar item needs just the totals.
    var windowIsOpen = false {
        // Fresh Top Apps at once on open. Not when stopped: snapshots stage their own numbers.
        didSet { if windowIsOpen && !oldValue && loop != nil { Task { await refresh() } } }
    }

    private let source: any MemorySource
    private var loop: Task<Void, Never>?

    init(source: any MemorySource) {
        self.source = source
        let saved = Store.defaults.integer(forKey: "refreshInterval")
        refreshInterval = Self.refreshChoices.contains(saved) ? saved : 2
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled, let self {
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.refreshInterval))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func restart() {
        guard loop != nil else { return }
        loop?.cancel()
        loop = nil
        start()
    }

    func refresh() async {
        let apps = windowIsOpen ? Self.runningApps() : nil
        let source = source
        let me = ProcessInfo.processInfo.processIdentifier
        let (stats, top) = await Task.detached(priority: .utility) {
            (source.stats(), apps.map { source.topApps(5, apps: $0, excluding: me) })
        }.value
        // Assign only changes: every assignment redraws the views that read it.
        if let stats, stats != self.stats { self.stats = stats }
        if windowIsOpen, let stats, stats != windowStats { windowStats = stats }
        if let top, top != topApps { topApps = top }
    }

    /// Snapshot mode sets the numbers it wants to show.
    func show(_ stats: MemoryStats, topApps: [AppUsage]) {
        self.stats = stats
        self.windowStats = stats
        self.topApps = topApps
    }

    /// Apps with a Dock icon. Menu bar apps and daemons are left out.
    private static func runningApps() -> [AppUsage] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { AppUsage(pid: $0.processIdentifier, name: $0.localizedName ?? "App",
                            bundlePath: $0.bundleURL?.path, bytes: 0) }
    }
}
