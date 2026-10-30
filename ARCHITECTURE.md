# MangoCleaner architecture

## Targets

- `MangoCleanerKit` — pure logic, no AppKit or SwiftUI: `MemoryStats`
  (breakdown math from kernel counters, pressure level), `AppUsageRanking`
  (groups helper processes under the responsible app, top five), `ByteText`.
  Unit tests in `Tests/MangoCleanerKitTests`.
- `MangoCleaner` — the app (depends on the Kit), default MainActor isolation.
- `MangoCleanerHelper` — a root launchd daemon registered with
  `SMAppService.daemon`. It exposes one XPC call, `clearFileCache`, which runs
  `/usr/sbin/purge` and takes no arguments. It accepts only callers that meet
  `Helper.clientRequirement` (MangoCleaner signed by team SJR7785KA2).
  `build.sh` embeds it in `Contents/MacOS` with its plist in
  `Contents/Library/LaunchDaemons`, signed with the hardened runtime.

## Layers in the app

```text
Views (MenuBarLabel, MemoryWindow, MemoryBreakdown, TopAppsList, CleanSection, SettingsView)
  -> AppModel (monitor, quitFlow, cleanFlow, focusedApp, settingsTab)
    -> MemoryMonitor -> MemorySource  [SystemMemorySource | SampleMemorySource]
    -> QuitFlow      -> AppQuitter    [SystemQuitter | FakeQuitter]
    -> CleanFlow     -> CacheClearer  [HelperCacheClearer (XPC) | FakeCacheClearer]
    -> AutoClear     (AutoClearRules, Kit)  -> CleanFlow
    -> PressureAlerts (PressureAlertRules, Kit) -> Notifier [SystemNotifier | FakeNotifier]
SystemMemory: host_statistics64, sysctl, proc_pid_rusage, responsible pid (nonisolated)
```

## Seams

- `MemorySource`: kernel numbers or fixed sample numbers. Test runs
  (`APP_STORE` set) always use the sample source.
- `AppQuitter`: real `NSRunningApplication` or a fake that records requests.
  Test runs never quit real apps.
- `CacheClearer`: the helper over XPC, or a fake. Test runs never run purge
  and never register the helper.

- `Notifier`: UserNotifications, or a fake that records. Test runs never post.

## Rules

- `MemoryMonitor.onStats` feeds every reading to `AutoClear` and `PressureAlerts`.
  Their rules are value types in the Kit with the clock passed in, so unit tests never wait.
- `MenuBarItem.toggle()` clicks the app's own status item: the one way the global
  shortcut (`GlobalHotKey`, Carbon), snapshots, and the self-test open the window.
- The pinned window is a `Window` scene (`PinnedWindow.id`). `MenuBarLabel`, which
  lives as long as the app, opens and closes it when `AppModel.pinned` changes.
  `MemoryMonitor` counts open memory windows (drop-down and pinned).
- The menu bar item is one image (`MenuBarLabel.image`): the menu bar shows a
  single image and ignores SwiftUI fonts.
- One 3-minute cooldown covers every clear. Automatic clears start it when they
  begin; clears from the button or the menu start it when they finish.

- `MemoryMonitor.refresh()` reads off the main thread and assigns only changed values.
- The menu bar label reads `stats`; window views read `windowStats`,
  `windowHistory`, `selfUsageLine`, and `topApps`, which change only while the window is open (docs/FIXLOG.md).
- Settings live in `Store.defaults` (a separate suite in test runs).
