# Architecture review — end of M1 (2026-10-29)

Survey: 2,076 lines in 24 files; largest `Snapshot.swift` (176) and
`TopAppsList.swift` (156). No duplicated private types. Pure logic (breakdown
math, Top Apps ranking, byte text) is in `MangoCleanerKit` with unit tests.
Two real seams with two adapters each: `MemorySource` (system, sample) and
`AppQuitter` (system, fake). One fix-log entry (CPU and memory from a hidden
window redrawing). Verdict: the code is in good shape; nothing is Strong.

## Clear File Cache behind a seam before M2  [Worth exploring]

Files: none yet (M2: S-010 to S-013).
Signal: before a big feature.
Problem: M2 adds a privileged `SMAppService.daemon` helper, a second
executable, a launchd plist inside the bundle, and XPC. Without a seam, the
window and the self-test would talk to XPC directly, and no test could run
without root.
Proposal:
```swift
protocol CacheClearer {
    var status: HelperStatus { get }          // .notRegistered, .needsApproval, .ready
    func register() throws                    // SMAppService.daemon(plistName:).register()
    func clear() async throws -> ClearReport  // runs purge in the helper
}
struct ClearReport: Sendable { var before: MemoryStats; var after: MemoryStats }
```
Adapters: `HelperCacheClearer` (XPC) and `FakeCacheClearer` (test runs).
Benefits: the window, gear menu, and later auto-clear (S-014, S-015) share one
call; the self-test covers the flow without root.
Proof of same behavior: new feature; self-test and snapshots for each status.
Plan: 1) protocol and fake with snapshots, 2) helper target and build.sh embedding, 3) XPC adapter.

## Quit flow rules into the Kit  [Speculative]

Files: Sources/MangoCleaner/Memory/Quitter.swift (92 lines).
Signal: pure logic inside a @MainActor type.
Problem: the Quit → Quitting… → Force Quit rules are tested only by the
self-test, with real sleeps.
Proposal: a value-type state machine in the Kit, `QuitRules.next(state, event, now)`,
with `QuitFlow` keeping only the Task and the quitter.
Benefits: unit tests with no timing; small today, so low value now.

## One model for "what the window shows"  [Speculative]

Files: Memory/MemoryMonitor.swift.
Signal: fast-changing state observed by many views (fixed in FIXLOG).
Problem: the rule "window views read `windowStats`, only the label reads
`stats`" lives in a comment and DESIGN-SYSTEM.md.
Proposal: split into `menuBarFeed` and `windowFeed` objects so a view cannot
pick the wrong one. Worth it only if a second always-visible surface appears.

## Top recommendation

The CacheClearer seam, as the first step of M2 (not a refactor of M1 code).
Nothing applied in this check-in.

## Considered, not recommended

- Moving `SampleData` and `FakeQuitter` out of the app target: they are the
  test adapters the template expects there, and test runs need them in the app.
- Splitting `Snapshot.swift`: under 200 lines and only used by agents.

## Follow-up after M2

The top recommendation is done: `CacheClearer` with `HelperCacheClearer` (XPC)
and `FakeCacheClearer`, used by the window, the gear menu, and the self-test.
The two Speculative cards stand; nothing new reached Strong.

## Follow-up after M3 (2026-10-30)

Survey: 2,945 lines; largest `SelfTest.swift` and `Snapshot.swift` (both
under 300). M3 added two Kit rule types (`AutoClearRules`,
`PressureAlertRules`, unit tested with an injected clock) and a fourth real
seam, `Notifier` (system, fake). One fix-log entry (clock mix in the cooldown).

New card, **Speculative**: `AppModel.init` now picks four test or real
adapters with `if Store.isOverridden`. A `Dependencies` value (`.live`,
`.test`) would keep that choice in one place. Worth it when a fifth seam
arrives. Nothing reached Strong; nothing applied.

## Follow-up after M4 (2026-10-30)

M4 added `Shortcut` (Kit), `GlobalHotKey` (Carbon), and `MenuBarItem`, now
shared by snapshots, the self-test, and the shortcut. Key handling moved from
the Top Apps list to the window root, with `moveFocus` and `quitFocused` on
`AppModel`. The test-run fakes are now one `AppModel.fakes` tuple, a first
step toward the Speculative `Dependencies` card. Nothing reached Strong.

## Follow-up after M5 (2026-10-30)

M5 added `PressureHistory` (Kit ring buffer, unit tested), `PressureChart`
(Swift Charts, 60 bars), the help popover, and `selfUsage()` on
`MemorySource`, with a sample adapter. `CleanFlow` now takes several
`whenCleared` listeners. The window-only rule covers the new readings
(`windowHistory`, `selfUsageLine`). Idle: 20 MB, 0.0 % CPU. Nothing reached Strong.
