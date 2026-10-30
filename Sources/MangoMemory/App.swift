import AppKit
import SwiftUI

// MangoMemory
//   MangoMemory                      the app (menu bar only, no Dock icon)
//   APP_STORE=<file> MangoMemory     test run: settings go to a separate defaults suite
//   APP_SNAPSHOT=<dir> MangoMemory   save a PNG of the memory window and every Settings tab in light and dark mode, then quit
//   MangoMemory --selftest           run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MangoMemory      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MangoMemory           draw the 8 pt grid and the layout probes over the window

@main
struct MangoMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MemoryWindow()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Memory", id: PinnedWindow.id) {
            MemoryWindow(pinned: true)
                .environment(model)
                .themed()
                .background(PinnedWindow.Hook())
                .onDisappear { model.pinned = false }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app: no Dock icon, no main menu. Info.plist sets LSUIElement too.
        NSApp.setActivationPolicy(.accessory)
    }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

/// Where settings live. MangoMemory keeps no database: settings go to
/// UserDefaults, and test runs (APP_STORE set) use their own suite so they
/// never touch the real settings.
enum Store {
    /// True when APP_STORE is set (tests, snapshots, self-test).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static let defaults: UserDefaults = {
        guard isOverridden else {
            migrateFromMangoCleaner(into: .standard)
            return .standard
        }
        let suite = "com.mangocorp.mangomemory.test"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }()

    /// MangoMemory used to be called MangoCleaner (com.mangocorp.mangocleaner).
    /// The first launch copies its settings once; settings already set here win.
    private static func migrateFromMangoCleaner(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: "migrated.mangocleaner") else { return }
        if let old = defaults.persistentDomain(forName: "com.mangocorp.mangocleaner") {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: "migrated.mangocleaner")
    }
}
