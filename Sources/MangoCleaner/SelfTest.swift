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
