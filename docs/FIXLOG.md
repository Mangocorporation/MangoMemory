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
