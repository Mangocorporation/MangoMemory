# Memory Clean 2 — screen index

Reference app: Memory Clean 2 v2.1.2 (direct build, licensed, macOS 26, 24 GB Mac).
Captured 2026-10-29. It is a menu-bar-only app (`LSUIElement`), so computer use
could not grant it; screens were opened through System Events (Accessibility)
and captured per window with `screencapture -l`. Look only: no clean was run,
no setting was changed.

Structure and behavior only. Do not reuse its text, icon, colors-as-brand, or
name in MangoCleaner.

## 01-status-item.png

Page: menu bar status item. Always visible.
Layout: RAM-chip template glyph, then free memory as text ("3.39 GB").
Behavior: the number updates every refresh interval (default 5 s). The text
turns red when available memory falls below the Threshold Level (prefs >
Advanced). Prefs > General controls: icon on/off, text Default / Long / No
Text, text size Normal / Large, GB vs. percentage.
Actions: click opens the main window (02).

## 02-popover-default.png

Page: main window ("Memory Clean"). Reached from: click the status item.
Not a real NSPopover: a small 270×462 pt titled window with traffic lights,
placed under the status item, that closes when it loses focus (unless "Keep
window visible as background app" is on).
Layout, top to bottom:
1. Header band in a status color (red here, because available < comfortable
   level): huge thin number "3.22 GB", caption "AVAILABLE", gear button top right.
2. Stacked usage bar, full width: App Memory (yellow), Wired (red), Compressed
   (blue), Available (green); a thin gray strip under it marks Used.
3. "DETAILS" section header with a "?" help button; rows with color dot,
   label, bold right-aligned value: App Memory, Wired, Compressed, Used, then
   undotted File Cache and Total. Alternating row tint.
4. "MEMORY HOGS" section header with "?" help button; a centered row of app
   icons (top 2–3 apps by memory).
5. Two outlined buttons: "Clean" (blue) and "Unlock Extreme" (red, upsell).
Hover: each bar segment shows a tooltip with its name (04); each hog icon has
a tooltip "AppName: 341.06 MB".
Actions: Clean (standard clean), Unlock Extreme (on a licensed copy opens
prefs > Extras), gear (03), help buttons (05, 06).
Note: stays light even when the system is in Dark Mode (the gear menu is dark).

## 03-gear-menu.png

Page: gear menu. Reached from: gear button in the main window header.
Items: Clean Memory; Preferences ⌘,; Reset App Window; separator; live
read-only stats with color dots — Available, App Memory, Wired, Compressed,
Used, File Cache, Total (values right-aligned); separator; Customer Support;
Check for Updates; Join Mailing List; separator; Quit ⌘Q.

## 04-bar-hover-used.png

Page: main window, hovering the usage bar. A small dark-gray callout above the
bar names the hovered segment ("Used"). No values in the callout.

## 05-help-details.png

Page: DETAILS help popover. Reached from: "?" next to DETAILS.
A real popover to the right of the window with a bold term + one or two
sentence definition for each metric: Available Memory (free + file cache),
App Memory, Wired, Compressed, Used (excludes file cache), File Cache (counted
as available by the OS), Total (installed RAM).

## 06-help-hogs.png

Page: MEMORY HOGS help popover. Reached from: "?" next to MEMORY HOGS.
One sentence: shows the apps using the most memory, so you know which to quit.

## 07-prefs-general.png

Page: Preferences > General. Reached from: gear > Preferences (⌘,).
Window: 350 pt wide, toolbar-style tabs with icons: General, Advanced, Extras,
Licensing, About. Height changes per tab.
Group 1 (switches): Start at login (on); Hide window at startup; Keep window
visible as background app; Keep window above other apps (disabled until the
previous one is on); Show icon in dock; Hide Unlock Extreme Button.
Group 2 (status item): Use Percentages (switch); Icon Visible (switch); Text
(pop-up, 08); Text Size (pop-up, 09).

## 08-prefs-text-menu.png

Page: General > Text pop-up open. Options: Default, Long, No Text.

## 09-prefs-text-size-menu.png

Page: General > Text Size pop-up open. Options: Normal, Large.

## 10-prefs-advanced.png

Page: Preferences > Advanced.
Threshold Level slider (100 MB shown) + caption: below this the status bar
text turns red. Auto Clean checkbox + caption: clean automatically below the
threshold, at most once every 3 minutes. "Disable Auto Clean Cooldown (Not
Recommended)" checkbox, then a red live countdown "Auto Clean Cooldown: 31
seconds". Refresh Interval slider (5 seconds shown).

## 11-prefs-extras.png

Page: Preferences > Extras. Also reached from: Unlock Extreme button.
Two rows to carry over a purchase from the Mac App Store versions (title,
explanation, "Select …" button that opens a file picker for the old app), then
a red "Need help unlocking Extreme Clean?" with a Click Here button (web).

## Licensing (no screenshot)

Page: Preferences > Licensing. Opens a sheet immediately: "Your Memory Clean 2
License", a line saying this copy is registered, Email Address and License
Code fields, buttons Deactivate License and Close. Not captured on purpose:
it shows the owner's email and license code.

## 12-prefs-about.png

Page: Preferences > About. Large app icon, app name, version, copyright; a
bottom row of four link buttons (FAQ, Fan Page, Twitter, website).

## Not reached

- Clean in progress / result state: not triggered (it purges memory).
- Extreme Clean flow and the unlicensed purchase window: copy is licensed.
- Status item variants (Long text, percentages, red text): would need a
  settings change.
- Dark Mode of the main window: app does not adapt (see 02).

## Navigation map

- Status item (01) → main window (02)
- Main window header gear → gear menu (03)
  - Clean Memory → runs a clean
  - Preferences ⌘, → Preferences window, General tab (07)
  - Reset App Window → re-anchors the main window under the status item
  - Customer Support / Check for Updates / Join Mailing List → web / updater
  - Quit ⌘Q
- Main window "?" (DETAILS) → definitions popover (05)
- Main window "?" (MEMORY HOGS) → explanation popover (06)
- Main window Unlock Extreme → Preferences > Extras (11) when licensed
- Preferences tabs: General (07–09), Advanced (10), Extras (11), Licensing
  (sheet), About (12)

## Command map

| Where | Item | Shortcut |
| --- | --- | --- |
| Main window | Clean | — |
| Main window | Unlock Extreme | — |
| Gear menu | Clean Memory | — |
| Gear menu | Preferences | ⌘, |
| Gear menu | Reset App Window | — |
| Gear menu | Customer Support | — |
| Gear menu | Check for Updates | — |
| Gear menu | Join Mailing List | — |
| Gear menu | Quit | ⌘Q |
| Licensing sheet | Deactivate License, Close | — |
| About | FAQ, Fan Page, Twitter, website | — |

No main menu bar (agent app), no global hotkey, no context menu on the status
item (left click opens the window).

## Data model guess

- **MemorySnapshot**: available, appMemory, wired, compressed, used,
  fileCache, total (bytes); taken every refreshInterval.
- **MemoryHog**: app name, icon, bytes (top N running apps by footprint).
- **Settings**: startAtLogin, hideWindowAtStartup, keepWindowVisible,
  keepWindowOnTop, showDockIcon, hideUpsellButton, usePercentages,
  statusIconVisible, statusText (default | long | none), statusTextSize
  (normal | large), thresholdBytes, autoClean, disableAutoCleanCooldown,
  refreshInterval.
- **AutoCleanState**: lastCleanAt, cooldown remaining (3 min).
- **License**: email, code, extremeUnlocked.
