import AppKit
import IOKit.pwr_mgt
import MangoMemoryKit
import SwiftUI

/// Screenshot mode for agents.
///   APP_STORE=/tmp/MangoMemory-test APP_SNAPSHOT=/tmp/shots ~/Applications/MangoMemory.app/Contents/MacOS/MangoMemory
/// writes <page>-light.png and <page>-dark.png for every page in `Snapshot.pages`
/// (the memory window drops down from the menu bar item, as when clicked), and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// status-<level>.png shows the menu bar item at each pressure level.
/// APP_SNAPSHOT_PAGES=window,status-high limits the pages. Add "settings" to include Settings.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    /// The pages of the memory window. Add a page when a story adds a state
    /// that needs its own picture (docs/STORIES.md names them).
    static let pages: [(name: String, setup: (AppModel) -> Void)] = [
        ("window", { stage($0) }),
        ("window-high", { stage($0, level: .high) }),
        ("window-critical", { stage($0, level: .critical) }),
        ("window-row-hover", { stage($0, focus: SampleData.apps.first?.pid) }),
        ("window-force-quit", { model in
            stage(model)
            model.quitFlow.show(.refused, for: SampleData.apps[0].pid)
            model.quitFlow.show(.quitting, for: SampleData.apps[1].pid)
        }),
        ("helper-needed", { stage($0, helper: .notRegistered) }),
        ("helper-approval", { stage($0, helper: .needsApproval) }),
        ("window-cleaning", { stage($0, clean: .clearing) }),
        ("window-clean-result", { model in
            var after = SampleData.stats()
            after.free += 1_288_490_189
            after.pressurePercent = 26
            stage(model, clean: .done(CleanResult(date: .now, trigger: .button, before: SampleData.stats(), after: after)))
        }),
        ("window-help", { model in
            stage(model)
            model.showingHelp = true
        }),
        ("window-pinned", { model in
            stage(model)
            model.pinned = true
        }),
        ("window-clean-error", { stage($0, clean: .failed("Unable to clear the file cache. The helper didn't respond.")) }),
    ]

    /// The menu bar item at each pressure level (S-002).
    static let statusPages: [(name: String, level: PressureLevel)] =
        [("status-normal", .normal), ("status-high", .high), ("status-critical", .critical),
         ("status-pressure", .normal), ("status-icon-only", .normal), ("status-large", .normal)]

    private static func stage(_ model: AppModel, level: PressureLevel = .normal, focus: Int32? = nil,
                              helper: HelperStatus = .ready, clean: CleanFlow.State = .idle) {
        model.monitor.stop()
        model.cleanFlow.show(clean, helper: helper)
        model.monitor.show(SampleData.stats(level: level), topApps: SampleData.apps,
                           history: SampleData.history(), selfUsage: SampleData.selfUsage)
        model.showingHelp = false
        for app in SampleData.apps { model.quitFlow.show(nil, for: app.pid) }
        model.focusedApp = focus
    }

    /// Settings > Automation with clearing on after high pressure, a clear 2 minutes ago, and its cooldown.
    private static func stageAutomation(_ model: AppModel) {
        var after = SampleData.stats(level: .high)
        after.free += 943_718_400
        after.pressurePercent = 52
        let result = CleanResult(date: .now.addingTimeInterval(-130), trigger: .pressure,
                                 before: SampleData.stats(level: .high), after: after)
        model.autoClear.show(result, settings: (true, false))
    }

    /// Clicks MangoMemory's own menu bar item, like a person would, and
    /// returns the window that drops down.
    /// On a cold start after a fresh build the item can ignore the first clicks:
    /// poll for the window, and click again if it does not come.
    private static func openMenuBarWindow() async -> NSWindow? {
        let before = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
        func opened() -> NSWindow? {
            NSApp.windows.first { $0.isVisible && !before.contains($0.windowNumber) && !$0.className.contains("StatusBar") }
        }
        for _ in 1...3 {
            MenuBarItem.button?.performClick(nil)
            for _ in 1...20 {
                try? await Task.sleep(for: .milliseconds(100))
                if let window = opened() {
                    // Let the content lay out and settle before the capture.
                    try? await Task.sleep(for: .milliseconds(500))
                    return window
                }
            }
        }
        return nil
    }

    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in pages where only?.contains(page.name) ?? true {
                    page.setup(model)
                    if model.pinned {
                        try? await Task.sleep(for: .seconds(1.5))
                        capture(to: "\(dir)/\(page.name)-\(mode).png", window: PinnedWindow.window)
                        model.pinned = false
                        try? await Task.sleep(for: .seconds(0.5))
                        continue
                    }
                    guard let window = await openMenuBarWindow() else {
                        print("SNAPSHOT no menu bar window")
                        continue
                    }
                    capture(to: "\(dir)/\(page.name)-\(mode).png", window: window)
                    // A popover is a window of its own: capture it too.
                    if let popover = NSApp.windows.first(where: { $0.isVisible && $0.className.contains("Popover") }) {
                        // Let it finish appearing: mid-animation it is translucent and clipped.
                        try? await Task.sleep(for: .seconds(1))
                        capture(to: "\(dir)/\(page.name)-popover-\(mode).png", window: popover)
                        model.showingHelp = false
                        try? await Task.sleep(for: .seconds(0.3))
                    }
                    // A second click closes it, so the next click opens it again.
                    MenuBarItem.button?.performClick(nil)
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
            // The menu bar follows the desktop, not the app's appearance: one picture each.
            for page in statusPages where only?.contains(page.name) ?? true {
                stage(model, level: page.level)
                model.menuBarText = page.name == "status-pressure" ? .pressure : page.name == "status-icon-only" ? .iconOnly : .available
                model.largeMenuBarText = page.name == "status-large"
                try? await Task.sleep(for: .seconds(0.5))
                captureRegion(to: "\(dir)/\(page.name).png", of: MenuBarItem.button?.window)
            }
            model.menuBarText = .available
            model.largeMenuBarText = false
            if only == nil || only?.contains("settings") == true {
                stageAutomation(model)
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let settings = NSApp.windows.first { $0.isVisible && $0.canBecomeMain && !$0.isSheet }
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                    }
                }
            }
            if only == nil || only?.contains("about") == true {
                // The standard About panel (S-026), with the icon (S-027).
                // Close Settings, so the only window left to capture is About.
                // The panel is reused for the second mode, so it is not a new window then.
                for window in NSApp.windows where window.isVisible && !window.className.contains("StatusBar") {
                    window.close()
                }
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    NSApp.orderFrontStandardAboutPanel(nil)
                    try? await Task.sleep(for: .seconds(0.8))
                    let about = NSApp.windows.first { $0.isVisible && !$0.className.contains("StatusBar") }
                    capture(to: "\(dir)/about-\(mode).png", window: about)
                }
                for window in NSApp.windows where window.isVisible && !window.className.contains("StatusBar") {
                    window.close()
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// The menu bar item's window cannot be captured by window number:
    /// capture its rectangle of the screen instead.
    private static func captureRegion(to path: String, of window: NSWindow?) {
        guard let window, let screen = NSScreen.screens.first else { return }
        let frame = window.frame
        let top = screen.frame.maxY - frame.maxY
        let shot = Process()
        shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        shot.arguments = ["-x", "-R", "\(Int(frame.minX)),\(Int(top)),\(Int(frame.width)),\(Int(frame.height))", path]
        try? shot.run()
        shot.waitUntilExit()
        print("SNAPSHOT \(path)")
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
