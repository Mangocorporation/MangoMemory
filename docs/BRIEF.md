# MangoCleaner

A light, honest menu bar memory app for one Mac user: see memory pressure at a
glance, find the app eating RAM, quit it, or clear the file cache in one click.

Bundle id: `com.mangocorp.mangocleaner` (decided by the agent).

## Replaces
Memory Clean 2 (FIPLAB): Intel-only, unmaintained, upsells "Extreme Clean",
and shows free GB instead of pressure. See `docs/screens/INDEX.md`.

## Main jobs
1. Glance at the menu bar: is memory fine, tight, or critical (pressure color
   plus free GB)?
2. Open the window, see what uses memory (breakdown, last-hour pressure
   history, top 5 apps), and quit the app that is hogging it.
3. Clear the file cache in one click, or let it happen automatically when
   pressure stays high or a heavy app quits, and see what was freed.

## Data
No stored documents. In memory plus settings in `UserDefaults`.
- MemorySnapshot: date, pressure level (normal/warn/critical), pressure %,
  free, app, wired, compressed, file cache, swap used, total.
- AppUsage: pid, name, icon, footprint bytes.
- CleanResult: date, trigger (button/pressure/after-quit), freed bytes,
  pressure before and after.
- Settings: refresh interval (2 s), status text (GB / % / none), auto-clean
  on pressure (off), clean after heavy app quits (off), notify at warn or
  critical (on, quiet), launch at login (off), global shortcut.

## Shape
Menu bar extra (`MenuBarExtra`, window style, `LSUIElement`) with a gear menu
and a Settings window, macOS 26 or later, Apple silicon. Local data. Works
offline. No accounts. Direct distribution with Developer ID, notarized, not
sandboxed (sandbox blocks quitting apps; `purge` needs root).

## System hooks
Menu bar item; privileged `SMAppService.daemon` helper that runs `purge`;
`SMAppService.mainApp` launch at login (opt-in); global shortcut to open the
window (decided by the agent); user notifications for pressure.

## Reference
Memory Clean 2: same window order (headline, bar, details, hogs, Clean),
gear menu with live stats, Preferences tabs. Fix its faults: pressure first,
real top-apps list with Quit, no upsell, adapts to Dark Mode.

## Look
Native Mac look (Liquid Glass, system type, SF Symbols), follows light and
dark. Accent: mango orange (decided by the agent). Pressure colors green /
yellow / red are status colors, not brand.

## Not in version one
- Extreme or deep clean, and any allocate-and-touch "cleaning".
- Themes, compact mode, multiple menu bar widget styles.
- Idle-app timer that quits apps on its own; CPU, disk, network monitoring.
- Licensing, updater, mailing list, iCloud sync.
