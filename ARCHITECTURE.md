# MangoCleaner architecture

## Targets

- `MangoCleanerKit` — pure logic, no AppKit or SwiftUI: `MemoryStats`
  (breakdown math from kernel counters, pressure level), `AppUsageRanking`
  (groups helper processes under the responsible app, top five), `ByteText`.
  Unit tests in `Tests/MangoCleanerKitTests`.
- `MangoCleaner` — the app (depends on the Kit), default MainActor isolation.

## Layers in the app

```text
Views (MenuBarLabel, MemoryWindow, MemoryBreakdown, TopAppsList, SettingsView)
  -> AppModel (monitor, quitFlow, focusedApp, settingsTab)
    -> MemoryMonitor -> MemorySource  [SystemMemorySource | SampleMemorySource]
    -> QuitFlow      -> AppQuitter    [SystemQuitter | FakeQuitter]
SystemMemory: host_statistics64, sysctl, proc_pid_rusage, responsible pid (nonisolated)
```

## Seams

- `MemorySource`: kernel numbers or fixed sample numbers. Test runs
  (`APP_STORE` set) always use the sample source.
- `AppQuitter`: real `NSRunningApplication` or a fake that records requests.
  Test runs never quit real apps.

## Rules

- `MemoryMonitor.refresh()` reads off the main thread and assigns only changed values.
- The menu bar label reads `stats`; window views read `windowStats` and
  `topApps`, which change only while the window is open (docs/FIXLOG.md).
- Settings live in `Store.defaults` (a separate suite in test runs).
