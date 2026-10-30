# Fix log

## 2026-10-29 Menu bar app used 24 % CPU and grew to 190 MB

Symptom: idle at 24 % CPU with the window closed; with the window open,
21 % CPU and the footprint grew about 50 MB a minute (to 187 MB).
Cause: two things. (1) SwiftUI keeps a MenuBarExtra window's content alive
when it is closed, so every 2 s refresh redrew and animated it. (2)
`.contentTransition(.numericText())` on numbers that change every refresh is
rendered on the CPU (`RBInterpolatedDisplayListContents`, `TextAnimationSupport`)
and leaked malloc blocks. Found with `sample`, `footprint`, and one change per run.
Fix: the window reads `monitor.windowStats`, updated only while it is open;
Top Apps is read only while it is open; values are assigned only when they
change; no `numericText` on live numbers. Now 0.4 % CPU and 15 MB closed,
1.8 % CPU and 20 MB open.
Rule: Never animate values that refresh on a timer, and never let a hidden
MenuBarExtra window observe live data; measure CPU and footprint after every view change.

## 2026-10-29 Snapshots missed the first pages after a fresh build

Symptom: "SNAPSHOT no menu bar window" for window-light, window-high-light, and
window-critical-light; every later page worked.
Cause: on a cold start after a new build, the menu bar item ignored the first
clicks, and the snapshot waited a fixed 0.8 s once.
Fix: `openMenuBarWindow` polls for the window every 100 ms for 2 s and clicks
again, up to three times.
Rule: In snapshot and test tools, wait for a condition with a timeout and retry; never one fixed sleep.

## Automatic clear ran every reading after the first (caught by the self-test, 2026-10-30)

Symptom: a simulated High pressure stream started 11 clears in 200 seconds instead of 1.
Cause: `AutoClear` counted an automatic clear twice: when it began (the reading's
time) and again when it finished (the result's wall-clock date). The second moved
the cooldown back to an earlier time, so the next reading was already past it.
Fix: automatic clears start the cooldown once, when they begin; the end-of-clear
hook counts only clears from the button or the menu.
Rule: feed a time-based rule one clock. Never mix a passed-in `now` with `Date.now` from a callback.

## Arrow keys and ⌘K did nothing in the memory window until a click (2026-10-30)

Symptom: ↓, ↑, Return, ⌘K, and Escape did nothing right after the memory window opened.
Cause: the key handlers sat on the Top Apps list, which had focus only after a click;
the window itself was the first responder. ⌘K lived only on a gear menu item, whose
shortcut works only while the menu is open.
Fix: the window's root view is focusable (no focus effect), takes focus on appear,
and handles the keys. The self-test sends real key events to the real window.
Rule: test keyboard stories by sending key events to the opened window, never by calling the handler.

## Swap self-test check failed now and then (2026-10-30)

Symptom: "swap matches sysctl vm.swapusage" failed once in three runs with 8 GB of swap in use.
Cause: it compared the exact text ("7993.25M") of two reads taken a moment apart, while swap was moving.
Fix: parse the number and allow 3 %, like the other memory checks.
Rule: compare live system numbers with a tolerance, never as exact text.

## Large menu bar text looked like Regular (2026-10-30)

Symptom: Settings › General › Text size › Large changed nothing in the menu bar.
Cause: a MenuBarExtra label ignores SwiftUI fonts, and shows only the first Image of an HStack.
Fix: draw the glyph and the text into one NSImage (template at Normal, colored glyph and label-colored text at High and Critical).
Rule: in a MenuBarExtra label, put everything in one image; check each label variant on a status snapshot.

## Test runs saved the accent to the real settings (2026-10-30)

Symptom: none seen yet; found while adding iCloud sync, which reads and sets the accent.
Cause: ThemeStore read and wrote "appearance.accent" in UserDefaults.standard, not Store.defaults.
Fix: ThemeStore uses Store.defaults, like every other setting.
Rule: every setting goes through Store.defaults; grep for UserDefaults.standard after adding one.

## The dark About snapshot showed Settings (2026-10-30)

Symptom: about-dark.png was the Settings window.
Cause: the About panel is reused for the second mode, so it was not a "new" window, and the fallback matched Settings.
Fix: close every other window first, keep About open for both modes, and close it after.
Rule: when capturing a system panel, close the other windows first; never pick a window by "new since".

## Clear File Cache said "Nothing much to clear" after a real clear (2026-10-30)

Symptom: the first real clear through the helper said "Nothing much to clear"; the next said "Freed 136 MB", with about 3 GB of file cache before.
Cause: the result measured the change in *available* memory (free + file cache). purge turns file cache into free memory, so available hardly moves; what showed was background drift. The unit tests and sample data modeled a clear as free memory appearing from nowhere, so they agreed with the wrong measure.
Fix: measure the file cache that was emptied: "Cleared 2.1 GB · pressure 53 % → 52 %". Tests and sample data now model what purge does (cache down, free up by the same amount).
Rule: measure an action by the quantity it actually changes, and model fakes on the real system's behavior, not on the result you hope to show.

## The idle app used 3–5 % CPU with the window closed (2026-10-30)

Symptom: with the window closed, MangoMemory used 2.8–4.7 % CPU (0.0–0.3 % at the end of M1). A sample showed `processes()`, `AppRow.body`, and SwiftUI layout running, plus `SettingsSync.observe` firing every reading.
Cause, two parts:
1. M6 counted open memory windows (drop-down plus pinned). A window can report "appeared" more often than "disappeared", so the count stayed above zero after closing: the hidden window kept reading every process and redrawing every 2 seconds, the same failure as the first entry in this log.
2. The automation and alert settings were read through `rules`, which every pressure reading updates. Settings sync observes those settings, so it woke up every 2 seconds, re-read every setting, and asked SMAppService for the Open at login status each time.
Fix: one open flag per window (drop-down, pinned), never a count. `rules` is `@ObservationIgnored`; each setting is observed on its own key path. The self-test checks both. Idle is 0.47 % CPU, 14 MB.
Rule: track open/closed with a flag per window, never a counter; never expose a setting through state that changes on every reading.

## 2026-10-30 Downloaded zip rejected by Gatekeeper after some unzips
Symptom: "Not Opened" after unzipping the release zip with tools other than ditto; spctl:
"unsealed contents present in the root directory of an embedded framework".
Cause: `ditto -c -k` stored extended attributes as `._` files beside Sparkle.framework's symlinks
(xattr -cr skips symlinks). Found first in MangoStats 1.0; 0.1.3 had 166 such entries.
Fix: `xattr -crs` in build.sh, `ditto --norsrc --noextattr` in release.sh, and release.sh now
extracts the zip with plain `unzip` and requires Gatekeeper to accept it.
Rule: Test a release the way people open it (plain unzip, quarantined), not only with the tools that built it.
