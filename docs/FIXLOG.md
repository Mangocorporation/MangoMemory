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
