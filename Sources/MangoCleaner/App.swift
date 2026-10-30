import AppKit
import SwiftUI

// MangoCleaner
//   MangoCleaner                      the app (menu bar only, no Dock icon)
//   APP_STORE=<file> MangoCleaner     test run: settings go to a separate defaults suite
//   APP_SNAPSHOT=<dir> MangoCleaner   save a PNG of the memory window and every Settings tab in light and dark mode, then quit
//   MangoCleaner --selftest           run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> MangoCleaner      run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 MangoCleaner           draw the 8 pt grid and the layout probes over the window

@main
struct MangoCleanerApp: App {
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

/// Where settings live. MangoCleaner keeps no database: settings go to
/// UserDefaults, and test runs (APP_STORE set) use their own suite so they
/// never touch the real settings.
enum Store {
    /// True when APP_STORE is set (tests, snapshots, self-test).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static let defaults: UserDefaults = {
        guard isOverridden else { return .standard }
        let suite = "com.mangocorp.mangocleaner.test"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }()
}
