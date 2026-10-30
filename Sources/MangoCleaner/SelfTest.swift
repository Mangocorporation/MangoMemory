import AppKit
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
        let swapUsed = swap.split(separator: " ").firstIndex(of: "used").map { _ in true } ?? false
        check("swap matches sysctl vm.swapusage", swapUsed && swap.contains(String(format: "%.2fM", Double(stats.swapUsed) / 1_048_576)),
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
