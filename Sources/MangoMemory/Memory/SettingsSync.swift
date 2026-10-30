import Foundation
import MangoMemoryKit
import SystemConfiguration

/// Keeps settings the same on every Mac through iCloud Drive › MangoMemory ›
/// Settings.json. Each Mac writes the file a moment after a setting changes and
/// watches it for changes from the others; the newest change wins.
/// Test runs use a folder in /tmp, never iCloud Drive.
@Observable
final class SettingsSync {
    /// Settings › General › "Sync settings with iCloud". On by default.
    var enabled: Bool = Store.defaults.object(forKey: "sync.enabled") as? Bool ?? true {
        didSet {
            Store.defaults.set(enabled, forKey: "sync.enabled")
            enabled ? start() : stop()
        }
    }
    /// The last time settings went to or came from iCloud, and from which Mac.
    private(set) var lastSync: (date: Date, device: String)?
    /// Set when the file could not be saved, for the Settings footer.
    private(set) var failed = false

    /// False when iCloud Drive is off.
    var available: Bool { FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path) }

    let folder: URL
    var file: URL { folder.appending(path: "Settings.json") }
    private let read: () -> SyncedSettings.Values
    private let apply: (SyncedSettings.Values) -> Void
    /// What the file holds, so changes that came from it are not written back.
    private var lastKnown: SyncedSettings.Values?
    private var localModified: Date? {
        get { Store.defaults.object(forKey: "sync.modified") as? Date }
        set { Store.defaults.set(newValue, forKey: "sync.modified") }
    }
    private var watcher: FileWatcher?
    private var pendingWrite: Task<Void, Never>?
    private let device = SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "Mac"

    init(read: @escaping () -> SyncedSettings.Values, apply: @escaping (SyncedSettings.Values) -> Void) {
        self.read = read
        self.apply = apply
        if Store.isOverridden {
            let store = ProcessInfo.processInfo.environment["APP_STORE"] ?? "/tmp/MangoMemory-test"
            folder = URL(fileURLWithPath: store + "-iCloud/MangoMemory")
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } else {
            folder = FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Mobile Documents/com~apple~CloudDocs/MangoMemory")
        }
        if enabled { start() }
        observe()
    }

    /// Reads the file: applies it when another Mac changed it more recently.
    /// The file watcher calls this; the self-test calls it directly.
    func fileChanged() {
        guard enabled, let data = coordinatedRead(), let synced = try? SyncedSettings.decode(data) else { return }
        lastKnown = synced.values
        let local = read()
        if synced.replaces(local, changedAt: localModified) {
            apply(synced.values)
            localModified = synced.modified
            lastSync = (.now, synced.device)
        } else if synced.values != local {
            write()
        }
    }

    private func start() {
        guard available else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: file.path) {
            fileChanged()
        } else {
            write()
        }
        watcher = FileWatcher(url: file) { [weak self] in
            Task { @MainActor in self?.fileChanged() }
        }
    }

    private func stop() {
        watcher = nil
        pendingWrite?.cancel()
    }

    /// Calls `localChanged` whenever any synced setting changes.
    private func observe() {
        withObservationTracking {
            _ = read()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.localChanged()
                self?.observe()
            }
        }
    }

    private func localChanged() {
        let values = read()
        guard enabled, values != lastKnown else { return }
        localModified = .now
        // Wait a moment: a picker or several toggles in a row make one write.
        pendingWrite?.cancel()
        pendingWrite = Task {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { write() }
        }
    }

    private func write() {
        guard available else { return }
        let synced = SyncedSettings(values: read(), modified: localModified ?? .now, device: device)
        guard let data = try? synced.encoded() else { return }
        var error: NSError?
        var saved = false
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSFileCoordinator(filePresenter: watcher).coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            saved = (try? data.write(to: url, options: .atomic)) != nil
        }
        failed = error != nil || !saved
        if !failed {
            lastKnown = synced.values
            lastSync = (.now, device)
        }
    }

    private func coordinatedRead() -> Data? {
        var data: Data?
        var error: NSError?
        NSFileCoordinator(filePresenter: watcher).coordinate(readingItemAt: file, options: [], error: &error) { url in
            data = try? Data(contentsOf: url)
        }
        return data
    }
}

/// Tells the app when iCloud Drive (or anyone else) changes the file.
nonisolated private final class FileWatcher: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let onChange: @Sendable () -> Void

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = url
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit { NSFileCoordinator.removeFilePresenter(self) }

    func presentedItemDidChange() { onChange() }
}
