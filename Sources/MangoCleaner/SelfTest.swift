import AppKit
import Carbon.HIToolbox
import MangoCleanerKit

/// Self-test for agents: runs the app's real functions, prints PASS or FAIL
/// per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/MangoCleaner-self ~/Applications/MangoCleaner.app/Contents/MacOS/MangoCleaner --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
/// Reads real memory (read-only); quits only fake apps.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a path in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            model.monitor.stop()

            check("test runs use their own settings", Store.defaults !== UserDefaults.standard)
            model.settingsTab = .appearance
            check("Settings remembers the last tab", Store.defaults.string(forKey: "settings.tab") == "appearance")
            check("runs without a Dock icon", NSApp.activationPolicy() == .accessory)

            readsRealMemory()
            readsRealApps()
            await quitFlow()
            await cleanFlow()
            await autoClear()
            await alerts(model)
            await keyboard(model)
            await insight(model)
            await polish(model)
            await iCloudSync(model)
            refreshInterval(model)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// S-001: our numbers come from the same counters as vm_stat and sysctl.
    private static func readsRealMemory() {
        guard let stats = SystemMemory.stats() else {
            check("reads memory from the kernel", false)
            return
        }
        check("reads memory from the kernel", stats.total > 0)
        check("the five parts add up to total",
              stats.app + stats.wired + stats.compressed + stats.fileCache + stats.free == stats.total)
        let vm = vmStat()
        let page = UInt64(getpagesize())
        if let wired = vm["Pages wired down"], let compressed = vm["Pages occupied by compressor"] {
            check("wired is within 3 % of vm_stat", close(stats.wired, wired * page),
                  "\(ByteText.string(stats.wired)) vs \(ByteText.string(wired * page))")
            check("compressed is within 3 % of vm_stat", close(stats.compressed, compressed * page),
                  "\(ByteText.string(stats.compressed)) vs \(ByteText.string(compressed * page))")
        } else {
            check("vm_stat runs", false)
        }
        let swap = shell("/usr/sbin/sysctl", ["-n", "vm.swapusage"])
        // "total = 10240.00M  used = 7993.25M  free = ...": swap moves between the two reads, so allow 3 %.
        let words = swap.split(separator: " ")
        let used = words.firstIndex(of: "used").flatMap { index -> UInt64? in
            guard index + 2 < words.count, let mb = Double(words[index + 2].dropLast()) else { return nil }
            return UInt64(mb * 1_048_576)
        }
        check("swap matches sysctl vm.swapusage", used.map { close(stats.swapUsed, $0) } ?? false,
              swap.trimmingCharacters(in: .whitespacesAndNewlines))
        print("INFO \(stats.level.title), \(stats.pressurePercent) % pressure, \(ByteText.string(stats.available)) available")
    }

    /// S-005: Top Apps reads real footprints, sorted, without MangoCleaner.
    private static func readsRealApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { AppUsage(pid: $0.processIdentifier, name: $0.localizedName ?? "App", bundlePath: nil, bytes: 0) }
        let me = ProcessInfo.processInfo.processIdentifier
        let top = SystemMemorySource().topApps(5, apps: apps, excluding: me)
        check("Top Apps lists running apps", !top.isEmpty)
        check("Top Apps is sorted largest first", top.map(\.bytes) == top.map(\.bytes).sorted(by: >))
        check("MangoCleaner is never in Top Apps", !top.contains { $0.pid == me })
        for app in top { print("INFO top app \(app.name) \(ByteText.string(app.bytes))") }
    }

    /// S-006, S-007: Quit, then Force Quit when the app ignores it. Fake apps only.
    private static func quitFlow() async {
        let quitter = FakeQuitter()
        let flow = QuitFlow(quitter: quitter)
        flow.patience = .milliseconds(200)
        let obeying = SampleData.apps[0], stubborn = SampleData.apps[1]

        flow.quit(obeying)
        check("Quit asks the app to quit normally", quitter.quitRequests == [obeying.pid])
        check("the row shows Quitting…", flow.states[obeying.pid] == .quitting)
        try? await Task.sleep(for: .milliseconds(400))
        check("an app that quits leaves no state", flow.states[obeying.pid] == nil)

        quitter.obeys = false
        flow.quit(stubborn)
        try? await Task.sleep(for: .milliseconds(400))
        check("an app that ignores Quit offers Force Quit", flow.states[stubborn.pid] == .refused)
        check("Force Quit is never sent without asking", quitter.forceQuitRequests.isEmpty)
        flow.forceQuit(stubborn)
        check("Force Quit closes the app", quitter.forceQuitRequests == [stubborn.pid] && flow.states[stubborn.pid] == nil)
        check("the confirmation names the app", ForceQuitText.title(stubborn) == "Force Quit Xcode?")
    }

    /// S-010 to S-013: Clear File Cache through the helper seam. Fake helper only.
    private static func cleanFlow() async {
        let clearer = FakeCacheClearer()
        clearer.status = .notRegistered
        var readings = [SampleData.stats()]
        var after = SampleData.stats()
        after.free += 1_288_490_189
        readings.append(after)
        let flow = CleanFlow(clearer: clearer) { readings.isEmpty ? nil : readings.removeFirst() }
        flow.resultDuration = .milliseconds(300)

        await flow.clear(trigger: .button)
        check("without the helper, nothing is cleared", clearer.clears == 0 && flow.state == .idle)
        flow.allowHelper()
        check("Allow Helper registers it and waits for approval", flow.helperStatus == .needsApproval)

        clearer.status = .ready
        await flow.clear(trigger: .button)
        if case .done(let result) = flow.state {
            check("a clear measures before and after", result.summary.hasPrefix("Freed 1.2 GB"), result.summary)
            check("the result names its trigger", result.trigger == .button)
        } else {
            check("a clear shows its result", false, "\(flow.state)")
        }
        check("the helper ran once", clearer.clears == 1)
        try? await Task.sleep(for: .milliseconds(500))
        check("the result line goes away", flow.state == .idle)

        clearer.fails = true
        await flow.clear(trigger: .menu)
        check("a helper error shows inline", flow.state == .failed("Unable to clear the file cache. The helper didn't respond."))
    }

    /// S-014, S-015: a simulated pressure stream clears once per cooldown,
    /// a big app quitting clears, and the settings are saved. Fake helper only.
    private static func autoClear() async {
        let clearer = FakeCacheClearer()
        let flow = CleanFlow(clearer: clearer) { SampleData.stats() }
        let auto = AutoClear(cleanFlow: flow) { [] }
        auto.whenPressureHigh = true
        auto.highFor = 60
        let start = Date.now
        var started: [Task<Void, Never>] = []
        for second in stride(from: 0.0, through: 200, by: 2) {
            if let task = auto.reading(.high, at: start + second) {
                started.append(task)
                await task.value
            }
        }
        check("pressure high for 1 minute clears once in the cooldown", started.count == 1 && clearer.clears == 1,
              "\(started.count) started, \(clearer.clears) cleared")
        if let task = auto.reading(.high, at: start + 250) { await task.value }
        check("after the cooldown, it clears again", clearer.clears == 2)
        check("the last automatic clear is shown", auto.lastResult?.trigger == .pressure)
        check("Clear automatically is saved", Store.defaults.bool(forKey: "auto.pressure"))

        let quitClearer = FakeCacheClearer()
        let quitFlow = CleanFlow(clearer: quitClearer) { SampleData.stats() }
        let afterQuit = AutoClear(cleanFlow: quitFlow) { SampleData.apps }
        afterQuit.whenPressureHigh = false
        afterQuit.afterBigQuit = true
        afterQuit.setAppSizes(SampleData.apps)
        check("a small app quitting does not clear", afterQuit.appQuit(pid: SampleData.apps[3].pid) == nil)
        if let task = afterQuit.appQuit(pid: SampleData.apps[0].pid) { await task.value }
        check("a big app quitting clears", quitClearer.clears == 1 && afterQuit.lastResult?.trigger == .afterQuit)
        afterQuit.afterBigQuit = false
        auto.whenPressureHigh = false
    }

    /// S-017: one notification when pressure turns critical, naming the top app. Fake notifier only.
    private static func alerts(_ model: AppModel) async {
        check("test runs never post real notifications", model.fakes != nil)
        let notifier = FakeNotifier()
        let alerts = PressureAlerts(notifier: notifier) { SampleData.apps.first }
        let start = Date.now
        for (second, level) in [(0.0, PressureLevel.normal), (2, .critical), (4, .critical), (6, .high), (8, .critical)] {
            await alerts.reading(level, at: start + second)?.value
        }
        check("one notification per level change, then quiet", notifier.posted.count == 1, "\(notifier.posted.count) posted")
        check("the notification names the top app",
              notifier.posted.first?.body == "Safari uses the most memory: 6.1 GB." && notifier.posted.first?.quit?.name == "Safari")
        check("notify when Critical is on by default", alerts.whenCritical && !alerts.whenHigh)
    }

    /// S-018, S-019: the shortcut, and the memory window driven by keys alone.
    /// Keys go through the app's own event queue to the real window.
    private static func keyboard(_ model: AppModel) async {
        check("the default shortcut is ⌃⌥M", model.shortcut?.display == "⌃⌥M")
        guard let fakes = model.fakes else { return }
        model.monitor.stop()
        model.monitor.show(SampleData.stats(), topApps: SampleData.apps)
        model.focusedApp = nil
        guard let window = await openWindow() else {
            check("the menu bar item opens the memory window", false)
            return
        }
        check("the menu bar item opens the memory window", true)
        key(kVK_DownArrow, "\u{F701}", in: window)
        key(kVK_DownArrow, "\u{F701}", in: window)
        check("↓ selects app rows", model.focusedApp == SampleData.apps[1].pid)
        key(kVK_UpArrow, "\u{F700}", in: window)
        check("↑ moves the selection up", model.focusedApp == SampleData.apps[0].pid)
        key(kVK_Return, "\r", in: window)
        check("Return quits the selected app", fakes.quitter.quitRequests == [SampleData.apps[0].pid])
        let clears = fakes.clearer.clears
        key(kVK_ANSI_K, "k", flags: .command, in: window)
        try? await Task.sleep(for: .seconds(1.5))
        check("⌘K clears the file cache", fakes.clearer.clears == clears + 1)
        key(kVK_Escape, "\u{1B}", in: window)
        try? await Task.sleep(for: .seconds(0.5))
        check("Escape closes the window", !window.isVisible)
    }

    private static func openWindow() async -> NSWindow? {
        let before = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        MenuBarItem.toggle()
        for _ in 1...30 {
            try? await Task.sleep(for: .milliseconds(100))
            if let window = NSApp.windows.first(where: {
                $0.isVisible && !before.contains($0.windowNumber) && !$0.className.contains("StatusBar")
            }) {
                try? await Task.sleep(for: .milliseconds(500))
                return window
            }
        }
        return nil
    }

    private static func key(_ code: Int, _ characters: String, flags: NSEvent.ModifierFlags = [], in window: NSWindow) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                                               timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: window.windowNumber, context: nil,
                                               characters: characters, charactersIgnoringModifiers: characters,
                                               isARepeat: false, keyCode: UInt16(code)) else { continue }
            NSApp.sendEvent(event)
        }
    }

    /// S-020, S-022: the hour of history fills from readings and marks clears;
    /// MangoCleaner's own footprint stays small.
    private static func insight(_ model: AppModel) async {
        let monitor = MemoryMonitor(source: SampleMemorySource())
        monitor.windowIsOpen = true
        await monitor.refresh()
        await monitor.refresh()
        monitor.recordClean(at: .now)
        check("each reading adds to the hour of history", monitor.windowHistory.samples.count == 2)
        check("a clear is marked on the chart", monitor.windowHistory.clears.count == 1)
        check("MangoCleaner's own use is shown", monitor.selfUsageLine == SampleData.selfUsage,
              monitor.selfUsageLine ?? "nil")
        // Not idle here: the self-test just drew every view. Idle is measured on the
        // running app with `footprint` (docs/STORIES.md, S-022).
        let footprint = SystemMemory.selfUsage().footprint
        check("reads MangoCleaner's own footprint", footprint > 0, ByteText.string(footprint))
    }

    /// S-023 to S-025: menu bar text, Open at login (pretend), and the pinned window.
    private static func polish(_ model: AppModel) async {
        model.menuBarText = .pressure
        model.largeMenuBarText = true
        check("the menu bar choice is saved",
              Store.defaults.string(forKey: "menuBar.text") == "pressure" && Store.defaults.bool(forKey: "menuBar.large"))
        model.menuBarText = .available
        model.largeMenuBarText = false
        model.openAtLogin = true
        check("Open at login turns on (test runs only pretend)", model.openAtLogin)
        model.openAtLogin = false

        model.pinned = true
        var pinned: NSWindow?
        for _ in 1...30 where pinned == nil {
            try? await Task.sleep(for: .milliseconds(100))
            pinned = PinnedWindow.window
        }
        try? await Task.sleep(for: .milliseconds(300))
        check("Keep Window Open floats the window", pinned?.level == .floating)
        model.pinned = false
        try? await Task.sleep(for: .milliseconds(500))
        check("Return to Menu Bar closes the floating window", PinnedWindow.window == nil)
        let window = await openWindow()
        check("the window drops down from the menu bar item again", window != nil)
        if window != nil { MenuBarItem.button?.performClick(nil) }
    }

    /// iCloud sync: a change here reaches the file; a newer file from another Mac
    /// applies here; an older one does not. Test runs use a folder in /tmp.
    private static func iCloudSync(_ model: AppModel) async {
        let sync = model.settingsSync!
        check("test runs sync through /tmp, never iCloud Drive", sync.folder.path.hasPrefix("/tmp/"), sync.folder.path)
        model.menuBarText = .pressure
        try? await Task.sleep(for: .seconds(1.8))
        let written = (try? Data(contentsOf: sync.file)).flatMap { try? SyncedSettings.decode($0) }
        check("a change here is written to the synced file", written?.values.menuBarText == "pressure",
              written?.values.menuBarText ?? "no file")

        guard var values = written?.values else { return }
        values.menuBarText = MenuBarText.iconOnly.rawValue
        values.notifyHigh = true
        try? SyncedSettings(values: values, modified: .now.addingTimeInterval(5), device: "Other Mac").encoded().write(to: sync.file)
        sync.fileChanged()
        check("a newer change from another Mac applies here",
              model.menuBarText == .iconOnly && model.alerts.whenHigh && sync.lastSync?.device == "Other Mac")

        values.menuBarText = MenuBarText.available.rawValue
        try? SyncedSettings(values: values, modified: .distantPast, device: "Old Mac").encoded().write(to: sync.file)
        sync.fileChanged()
        check("an older file from another Mac changes nothing", model.menuBarText == .iconOnly)

        // Like iCloud Drive: a coordinated write the watcher hears about, with no direct call.
        values.menuBarText = MenuBarText.available.rawValue
        values.largeMenuBarText = true
        if let data = try? SyncedSettings(values: values, modified: .now.addingTimeInterval(10), device: "iCloud Mac").encoded() {
            var error: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: sync.file, options: .forReplacing, error: &error) { url in
                try? data.write(to: url, options: .atomic)
            }
        }
        for _ in 1...30 where !model.largeMenuBarText { try? await Task.sleep(for: .milliseconds(100)) }
        check("the file watcher applies a change iCloud Drive writes", model.largeMenuBarText && model.menuBarText == .available)

        model.largeMenuBarText = false
        model.alerts.whenHigh = false
        try? await Task.sleep(for: .seconds(1.5))
    }

    /// S-009: the refresh interval is saved.
    private static func refreshInterval(_ model: AppModel) {
        model.monitor.refreshInterval = 5
        model.monitor.stop()
        check("the refresh interval is saved", Store.defaults.integer(forKey: "refreshInterval") == 5)
        check("a new monitor reads the saved interval", MemoryMonitor(source: SampleMemorySource()).refreshInterval == 5)
    }

    private static func close(_ a: UInt64, _ b: UInt64) -> Bool {
        let larger = Double(max(a, b)), smaller = Double(min(a, b))
        return larger == 0 || (larger - smaller) / larger <= 0.03
    }

    private static func vmStat() -> [String: UInt64] {
        var result: [String: UInt64] = [:]
        for line in shell("/usr/bin/vm_stat", []).split(separator: "\n") {
            let parts = line.split(separator: ":")
            guard parts.count == 2 else { continue }
            let number = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if let value = UInt64(number) { result[String(parts[0])] = value }
        }
        return result
    }

    private static func shell(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
