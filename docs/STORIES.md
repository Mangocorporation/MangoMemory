# MangoCleaner stories

From `docs/BRIEF.md`, `docs/research/memory-cleaners.md`, and
`docs/screens/INDEX.md` (reference: Memory Clean 2). Reference screenshots live
in `docs/screens/`; MangoCleaner snapshot pages are named in each story.
Decided by the agent without an interview, per "keep working".

## M1 Glance and act

Done when MangoCleaner sits in the menu bar, its numbers match Activity
Monitor, and quitting a top app from the window works. Settings survive a restart.

### S-001 Read memory stats once
As the user, I trust the numbers because they come from the kernel the same
way Activity Monitor's do.
Screens: none (model)
Acceptance:
- [unit] `MemoryReader` returns total, free, app, wired, compressed, file cache, swap used, pressure level (normal/warn/critical) and pressure %, using Stats' formulas (research Platform).
- [unit] app + wired + compressed + file cache + free = total, within 1 %.
- [self] On this Mac, each value is within 3 % of `vm_stat` and `sysctl vm.swapusage` output.
Status: done

### S-002 See pressure and free memory in the menu bar
As the user, I glance at the menu bar and see a memory glyph tinted by pressure, plus free GB.
Screens: 01-status-item.png; snapshot `status-item` (normal, warn, critical)
Depends: S-001
Acceptance:
- [snap] Glyph plus "3.4 GB" text; glyph is the template color at normal, yellow at warn, red at critical.
- [self] The text updates every refresh interval (default 2 s) without growing memory over 10 minutes.
- [manual] Readable in a light and a dark menu bar, and next to a notch.
UX:
- Flow: launch -> menu bar item appears at once with the last known value -> updates every refresh interval -> click opens the memory window (S-003)
- Surface: menu bar item (always-visible status, no action needed)
- States: first read pending or a reader error shows the plain glyph without text; Critical adds a filled glyph, not just red
- Words: "3.4 GB" (available). No tooltip: MenuBarExtra labels ignore `.help`; the window header says the rest
- Access: VoiceOver "MangoCleaner, memory pressure Normal, 3.4 GB available"; Normal outline template, High yellow outline, Critical filled red
Status: done

### S-003 Open the memory window from the menu bar
As the user, I click the status item and a window drops down with the pressure headline.
Screens: 02-popover-default.png; snapshot `window` (light, dark)
Depends: S-002
Acceptance:
- [snap] Header shows pressure state word (Normal / High / Critical) large, with free GB and pressure % under it, tinted by pressure.
- [snap] Follows system light and dark mode (Memory Clean 2 does not).
- [self] Clicking outside or pressing Escape closes it; clicking the item again toggles it.
UX:
- Flow: click the menu bar item or the global shortcut (S-018) -> memory window drops down under it, focus on the top apps list -> Escape, click outside, or click the item again closes it
- Surface: menu bar extra window (`MenuBarExtra(.window)`): a place people come back to many times a day, lighter than a full window
- States: first open before a read shows the last snapshot, never a spinner; pressure % missing shows the level word only
- Words: header "Memory Pressure" caption, level word "Normal" / "High" / "Critical" with a symbol, sub-line "3.4 GB available · 41 % pressure"
- Access: the level is a word and a symbol, not only a color; the header reads as one VoiceOver element
Status: done

### S-004 See the memory breakdown
As the user, I see where my RAM goes in a stacked bar and a details list.
Screens: 02-popover-default.png, 04-bar-hover-used.png; snapshot `window`
Depends: S-003
Acceptance:
- [snap] Stacked bar: App, Wired, Compressed, File cache, Free, each with its own color; rows below with a matching dot, name, and value, then Swap used and Total.
- [self] Hovering a bar segment shows its name and value.
- [unit] Segment widths are proportional to values and sum to the bar width.
UX:
- Flow: open the memory window -> bar and rows are visible without scrolling -> hover a bar segment for its value
- Surface: inline in the memory window (information, no action)
- States: Swap row shows "None" when zero; values under 1 GB show in MB; total never changes
- Words: rows "App memory", "Wired", "Compressed", "File cache", "Free", "Swap", "Total"; segment tooltip "Compressed · 9.6 GB"
- Access: each row is one VoiceOver element "Compressed, 9.6 GB"; dot colors repeat in the bar but every value also has its word
Status: done

### S-005 See which apps use the most memory
As the user, I see the five apps using the most memory, with icon, name, and size.
Screens: 02-popover-default.png; snapshot `window`
Depends: S-003
Acceptance:
- [unit] `AppUsageReader` groups helper processes under their parent app bundle and sorts by footprint (`proc_pid_rusage` `ri_phys_footprint`).
- [self] The top app matches Activity Monitor's Memory tab top entry.
- [snap] Rows show icon, app name, and size in GB or MB; MangoCleaner itself is never listed.
UX:
- Flow: open the memory window -> "Top Apps" section lists five rows, live -> a row moves when its size changes, without animation jumps
- Surface: inline list in the memory window (a place to come back to; actions come in S-006)
- States: fewer than five apps lists what exists; footprint unreadable for an app shows "—" with tooltip "macOS doesn't share this app's memory"; long names truncate with a tooltip
- Words: section title "Top Apps"; row "Safari  6.1 GB"
- Access: rows are focusable list items in order; VoiceOver "Safari, 6.1 GB"
Status: done

### S-006 Quit a top app from the memory window
As the user, I hover an app row and click Quit to free its memory.
Screens: snapshot `window-row-hover`
Depends: S-005
Acceptance:
- [snap] Hovering a row reveals a Quit button; the row is also reachable with arrow keys (window-row-hover).
- [self] Quit sends a normal terminate; the row disappears once the app exits.
- [manual] An app with unsaved changes shows its own save dialog (we never force quit by default).
UX:
- Flow: hover a top-apps row or select it with arrows -> Quit button appears in the row -> click or Return -> row shows "Quitting…" -> row leaves when the app exits; the app's own save dialog appears if needed
- Surface: inline button in the row (acts on one thing already on screen); also in the row's context menu
- States: quitting in progress dims the row; app refused (still running after 5 s) leads to S-007; no confirmation, because Quit lets the app save
- Words: button "Quit"; tooltip "Quit Safari and free 6.1 GB (Return)"; context menu "Quit Safari", "Show in Activity Monitor"
- Access: Return quits the selected row; VoiceOver action "Quit"; the button never shifts the row's layout
Status: done

### S-007 Force quit an app that won't quit
As the user, when an app ignores Quit for 5 seconds, I can force quit it.
Screens: snapshot `window-force-quit`
Depends: S-006
Acceptance:
- [snap] After 5 s the row's button becomes Force Quit with a warning tint (window-force-quit).
- [self] Force Quit asks for confirmation that names the app and warns about unsaved work.
UX:
- Flow: Quit sent, app still running after 5 s -> row button becomes "Force Quit" -> click -> confirmation dialog -> Force Quit closes the app, Cancel or Escape returns to the row
- Surface: confirmation dialog (rare, destroys unsaved work, can't be undone)
- States: app quits by itself during the dialog closes the dialog; dialog never shows for MangoCleaner itself
- Words: title "Force Quit Safari?"; message "Safari isn't responding to Quit. Any unsaved changes in Safari will be lost."; buttons "Force Quit" (destructive) and "Cancel" (default)
- Access: Escape cancels, Return is Cancel; warning tint plus the words "Force Quit"
Status: done

### S-008 Open settings and quit from the gear menu
As the user, I open a gear menu in the window for Settings and Quit, with live stats.
Screens: 03-gear-menu.png; snapshot `gear-menu`
Depends: S-003
Acceptance:
- [manual] Items: Clear File Cache (from S-013), Settings… ⌘,, separator, live stats (Free, App memory, Wired, Compressed, File cache, Swap, Total), separator, About MangoCleaner, Quit MangoCleaner ⌘Q.
- [self] ⌘, opens the Settings window; ⌘Q quits.
UX:
- Flow: gear button in the memory window header -> menu opens -> choose an item; Escape closes (MenuBarExtra has no right-click)
- Surface: menu (a few related commands tied to one control)
- States: live stats are disabled items with the values from when the menu opened; Clear File Cache arrives with S-013
- Words: "Clear File Cache", "Settings… ⌘,", stats "Free  3.4 GB" etc., "About MangoCleaner", "Quit MangoCleaner ⌘Q"; gear tooltip "Show settings and more"
- Access: gear button VoiceOver "More"; full menu keyboard navigation
Status: done

### S-009 Change how often numbers refresh
As the user, I set the refresh interval and it survives a restart.
Screens: 10-prefs-advanced.png; snapshot `settings-general`
Depends: S-008
Acceptance:
- [snap] Settings > General has a Refresh interval picker: 1, 2, 5, 10 s.
- [unit] The value is stored in UserDefaults and read back after relaunch.
- [self] Idle CPU of MangoCleaner stays under 0.5 % at 2 s.
UX:
- Flow: gear > Settings… or ⌘, -> Settings window opens on General -> pick Refresh interval -> applies at once, no Save button
- Surface: Settings window (`Settings` scene), General tab: a place people come back to rarely; inline picker inside it
- States: values below 2 s show a note "Faster refresh uses more energy."
- Words: label "Refresh interval", options "1 second", "2 seconds", "5 seconds", "10 seconds"; window title "General"
- Access: picker reachable with Tab; VoiceOver "Refresh interval, 2 seconds, pop-up button"
Status: done

## M2 Clean

Done when the Clear File Cache button works through the helper and shows what it freed.

### S-010 Install the cleaning helper
As the user, the first time I clean, I am asked once to allow a helper that can clear the file cache.
Screens: snapshot `helper-needed`
Depends: S-008
Acceptance:
- [snap] The window explains in one sentence why the helper is needed and has an Allow button.
- [manual] Allow registers the `SMAppService.daemon`; macOS shows it in Login Items; approving it there enables cleaning.
- [self] When the helper is missing or disabled, Clean shows the same explanation instead of failing.
UX:
- Flow: open the memory window -> bottom shows one sentence and "Allow Helper…" -> click registers the SMAppService daemon -> System Settings › Login Items opens; the window says "Turn on MangoCleaner in System Settings › Login Items to finish." with "Open Login Items" -> once on, the window shows Clear File Cache next time it opens
- Surface: inline in the memory window (the place the action lives), no sheet
- States: not registered, needs approval, ready (snapshots helper-needed, helper-approval, window)
- Words: "Clearing the file cache needs a small helper with admin rights. macOS asks you once." / "Allow Helper…" / "Open Login Items"
- Access: one prominent button per state; VoiceOver reads the sentence then the button
Status: done

### S-011 Clear the file cache in one click
As the user, I click Clear File Cache in the window and the helper runs `purge`.
Screens: 02-popover-default.png; snapshot `window-cleaning`
Depends: S-010
Acceptance:
- [snap] A full-width button at the bottom of the window; while running it shows a progress indicator and is disabled.
- [self] The helper runs only `/usr/sbin/purge`, takes no arguments from the app, and returns its exit code.
- [manual] The window stays responsive during the clean.
UX:
- Flow: click Clear File Cache or ⌘K, or gear › Clear File Cache -> button shows a spinner and "Clearing File Cache…", disabled -> result line (S-012)
- Surface: full-width prominent button at the bottom of the memory window (the one primary action)
- States: clearing (window-cleaning); error inline in red with a triangle: "Unable to clear the file cache. The helper didn't respond." (window-clean-error)
- Words: "Clear File Cache", "Clearing File Cache…"; tooltip "Empty the file cache now (⌘K). macOS refills it as you open files."
- Access: dark text on the Mango fill (Palette.onAccent); the spinner has the words next to it
Status: done

### S-012 See what a clean freed
As the user, after a clean I see the before and after free memory and pressure.
Screens: snapshot `window-clean-result`
Depends: S-011
Acceptance:
- [snap] A result line: "Freed 1.2 GB · pressure 62 % → 48 %", shown for 10 seconds (window-clean-result).
- [unit] `CleanResult` stores trigger, freed bytes, and pressure before and after.
- [self] When less than 50 MB is freed, the line says so honestly ("Nothing much to clear").
UX:
- Flow: after a clear -> one line under the button for 10 s -> fades away
- Surface: inline line (information, no action)
- States: "Freed 1.2 GB · pressure 34 % → 26 %" with a check, or "Nothing much to clear" with an info symbol under 50 MB (window-clean-result)
- Words: as above; never "boost", "optimize", or "free up"
- Access: the line is plain text VoiceOver reads after the button
Status: done

### S-013 Clear File Cache from the gear menu
As the user, I choose Clear File Cache from the gear menu.
Screens: 03-gear-menu.png; snapshot `gear-menu`
Depends: S-011, S-008
Acceptance:
- [self] The menu item runs the same clean as the button and shows the same result.
UX:
- Flow: gear › Clear File Cache (⌘K) -> same flow and result as the button
- Surface: menu item (same command as the button)
- States: disabled while clearing or while the helper is not ready
- Words: "Clear File Cache"
- Access: full keyboard menu navigation
Status: done

## M3 Automation

Done when MangoCleaner can clean on its own without nagging.

### S-014 Clear automatically when pressure stays high
As the user, I turn on Auto clean and it clears the file cache when pressure stays at warn for a set time.
Screens: 10-prefs-advanced.png; snapshot `settings-automation`
Depends: S-012
Acceptance:
- [snap] Settings > Automation: "Clear automatically when pressure stays high" toggle (off by default) and a duration picker (30 s, 1 min, 5 min).
- [unit] The trigger fires only after the level has been warn or critical for the full duration, then waits a 3-minute cooldown.
- [self] A simulated pressure stream triggers exactly one clean per cooldown.
UX:
- Flow: Settings (⌘,) › Automation › "Clear automatically when pressure stays high" -> pick 30 seconds, 1 minute, or 5 minutes -> clears run on their own; the result line shows in the memory window
- Surface: inline toggle and picker in a Settings tab (changes one value)
- States: picker disabled while the toggle is off; helper not ready: footer text plus "Allow Helper…" or "Open Login Items"
- Words: "Clear automatically when pressure stays high", "Pressure high for"
- Access: Tab between the toggle and the picker; VoiceOver reads the label text
Status: done

### S-015 Clear automatically after a big app quits
As the user, I turn on "Clean after a heavy app quits" so memory frees when I close a big app.
Screens: snapshot `settings-automation`
Depends: S-014
Acceptance:
- [snap] Toggle (off by default) with a threshold picker: apps over 1, 2, or 4 GB.
- [unit] Fires when an app that was over the threshold in the last snapshot terminates; respects the shared cooldown.
UX:
- Flow: Settings › Automation › "Clear automatically after a big app quits" -> pick 1, 2, or 4 GB -> quitting a bigger app clears
- Surface: inline toggle and picker under the pressure toggle
- States: picker disabled while off; shares the 3-minute cooldown with every clear, the button too
- Words: "Clear automatically after a big app quits", "Big app uses more than"
- Access: as S-014
Status: done

### S-016 See when the file cache was last cleared automatically
As the user, I see when the last automatic clean ran and what it freed.
Screens: 10-prefs-advanced.png; snapshot `settings-automation`
Depends: S-014
Acceptance:
- [snap] A line under the toggles: "Last auto clean 4 min ago · freed 900 MB" or "Next possible in 2:10".
UX:
- Flow: open Settings › Automation -> read the footer
- Surface: section footer text (information, no action)
- States: none yet: no line; after a clear: "Last automatic clear 4 min ago · freed 900 MB."; during the cooldown also "Next possible in 2:10."
- Words: "Last automatic clear", "Next possible in" (glossary: Clear automatically, never "auto clean")
- Access: plain text, read by VoiceOver
Status: done

### S-017 Get a quiet alert when pressure is critical
As the user, I get one notification when pressure turns critical, naming the top app.
Screens: snapshot `settings-notifications`
Depends: S-005
Acceptance:
- [snap] Settings > Notifications: "Notify when pressure is critical" (on), "Also when High" (off).
- [unit] No more than one alert per level change, and none again for 30 minutes.
- [manual] The notification reads "Memory is critical — Safari uses 6.1 GB" and has a Quit Safari action.
UX:
- Flow: pressure turns Critical -> one notification "Memory pressure is Critical", "Safari uses the most memory: 6.1 GB." -> "Quit Safari" button quits it like the Top Apps Quit -> none again for 30 minutes unless pressure climbs higher
- Surface: system notification (information people may act on); settings in Settings › Notifications
- States: permission asked the first time it posts; denied: nothing posts; no app found: "Open MangoCleaner to see what uses memory."
- Words: "Notify when pressure is Critical" (on), "Notify when pressure is High" (off), "Quit <app>"
- Access: notifications are read by VoiceOver; the button is in the notification's actions
Status: done

## M4 Speed

### S-018 Open the window with a global shortcut
As the user, I press a shortcut anywhere to open the memory window.
Screens: snapshot `settings-general`
Depends: S-003
Acceptance:
- [snap] Settings > General has a shortcut recorder (default ⌃⌥M).
- [manual] The shortcut opens the window from any app and toggles it closed.
UX:
- Flow: ⌃⌥M from any app -> the memory window drops down from the menu bar item -> ⌃⌥M or Escape closes it
- Surface: Settings › General › "Memory window shortcut": a recorder button (click, type, done)
- States: recording "Type Shortcut" (Escape cancels, Delete removes); taken by another app: red footer "Another app uses ⌃⌥M. Record a different shortcut."; removed: "Record Shortcut"
- Words: "Memory window shortcut", "Record Shortcut", "Type Shortcut", "Remove Shortcut"
- Access: the recorder is a button; tooltip says how to record
Status: done

### S-019 Use the window with the keyboard
As the user, I move through the top apps with arrows and act with the keyboard.
Screens: snapshot `window-row-hover`
Depends: S-006
Acceptance:
- [self] ↑/↓ select app rows, Return quits the selected app, ⌘K clears the file cache, Escape closes the window.
- [manual] VoiceOver reads each row as "Safari, 6.1 GB, Quit button".
UX:
- Flow: open the window -> ↓/↑ select a Top Apps row -> Return quits it (asks to Force Quit if it refused) -> ⌘K clears the file cache -> Escape closes
- Surface: the memory window; it takes the keys as soon as it opens, with no focus ring
- States: selection and hover share one highlight
- Words: unchanged
- Access: VoiceOver reads "Safari, 6.1 GB" with a Quit action
Status: done

## M5 Insight

### S-020 See the last hour of pressure
As the user, I see a small chart of pressure over the last hour in the window.
Screens: snapshot `window`
Depends: S-004
Acceptance:
- [snap] A 60-minute area chart under the breakdown, colored by level, with clean events marked.
- [unit] The history ring buffer keeps one sample per refresh for an hour and drops older ones.
UX:
- Flow: open the memory window -> the chart sits under the breakdown -> hover for what it shows
- Surface: inline in the window (information, no action)
- States: first minutes: few bars; each minute one bar in its level's color (Normal green, High yellow, Critical red); dashed accent line at each Clear File Cache
- Words: "1 hour ago", "Now", tooltip "Memory pressure over the last hour. Dashed lines mark each Clear File Cache."
- Access: VoiceOver reads "Pressure over the last hour: highest 69 %, 1 clear."
Status: done

### S-021 Learn what each number means
As the user, I hover a row or press the info button to read a one-line explanation in my own words.
Screens: 05-help-details.png, 06-help-hogs.png; snapshot `window-help`, `window-help-popover`
Depends: S-004
Acceptance:
- [snap] Each breakdown row has a tooltip; an info button opens a popover with one sentence per metric, including why "Free" being low is normal.
UX:
- Flow: hover a breakdown row -> one-sentence tooltip; or click (i) by the gear -> popover with every number -> Escape or click outside closes
- Surface: popover (a few related explanations tied to one control)
- States: one fixed text; Free explains that low Free is normal
- Words: button "What These Numbers Mean", tooltip "Explain what each number means"
- Access: rows carry the sentence as their VoiceOver hint
Status: done

### S-022 See MangoCleaner's own footprint
As the user, I see how much CPU and memory MangoCleaner itself uses.
Screens: snapshot `window`
Depends: S-005
Acceptance:
- [snap] A small footer line "MangoCleaner: 0.2 % CPU · 28 MB".
- [manual] Idle footprint stays under 40 MB: `footprint $(pgrep -x MangoCleaner)` after a minute idle read 20 MB, 0.0 % CPU (2026-10-30).
UX:
- Flow: open the window -> footer line at the bottom
- Surface: inline caption (information)
- States: shown after the second reading in an open window (CPU needs two readings)
- Words: "MangoCleaner: 0.2 % CPU · 28 MB"
- Access: plain text
Status: done

## M6 Settings and polish

### S-023 Choose what the menu bar shows
As the user, I choose the status text: free GB, pressure %, or icon only, and its size.
Screens: 07-prefs-general.png, 08-prefs-text-menu.png, 09-prefs-text-size-menu.png, 01-status-item.png; snapshot `settings-general`, `status-item`
Depends: S-002
Acceptance:
- [snap] Settings > General: "Menu bar shows" picker (Free memory, Pressure %, Icon only) and Text size (Regular, Large).
- [unit] Each choice renders the expected status title.
UX:
- Flow: Settings › General › "Menu bar shows" (Available memory, Pressure %, Icon only) and "Text size" (Regular, Large) -> the item changes at once
- Surface: inline pickers in Settings
- States: Text size disabled for Icon only; High and Critical keep their colored glyph in every choice
- Words: "Menu bar shows", "Available memory", "Pressure %", "Icon only", "Text size", "Regular", "Large"
- Access: VoiceOver always reads level and available memory, whatever the item shows
Status: done

### S-024 Start at login
As the user, I turn on Open at login.
Screens: 07-prefs-general.png; snapshot `settings-general`
Depends: S-008
Acceptance:
- [snap] "Open at login" toggle, off by default.
- [manual] With it on, MangoCleaner is in the menu bar after logging out and in.
UX:
- Flow: Settings › General › "Open at login" -> macOS adds MangoCleaner to Login Items
- Surface: inline toggle
- States: off by default; reflects System Settings if changed there
- Words: "Open at login"
- Access: standard toggle
Status: done

### S-025 Keep the window open while I work
As the user, I pin the window so it stays visible when I click elsewhere.
Screens: 07-prefs-general.png; snapshot `window-pinned`
Depends: S-003
Acceptance:
- [snap] A pin button in the window header; pinned, the window detaches and floats.
- [self] Return to Menu Bar (gear menu, pin button, or Escape) closes the floating window, and the drop-down opens under the status item again.
UX:
- Flow: pin button in the window header ("Keep Window Open") -> the drop-down closes and a floating window opens in the same place -> pin.slash button, gear › "Return to Menu Bar", Escape, or the close button put it back
- Surface: a floating window on every Space (a tool kept open beside the work)
- States: pinned window has only a close button; it is movable by its background
- Words: "Keep Window Open", "Return to Menu Bar"
- Access: both buttons have tooltips; Escape returns it
Status: done

### S-026 See an About window
As the user, I open About MangoCleaner from the gear menu.
Screens: 12-prefs-about.png; snapshot `about`
Depends: S-008
Acceptance:
- [snap] Standard About panel with the app icon, name, version, and copyright. No social links.
UX:
- Flow: gear › About MangoCleaner -> standard About panel
- Surface: the system About panel
- States: icon, name, version (build), "© 2026 MangoCorp"
- Words: "About MangoCleaner"
- Access: system panel
Status: done

### S-027 App icon
As the user, I see a MangoCleaner icon in Settings, About, and notifications.
Screens: snapshot `about`
Acceptance:
- [snap] Liquid Glass icon in all looks (made with the app-icon skill).
UX:
- Flow: shown in About, Settings, notifications, and Finder
- Surface: Icon Composer file Icon/AppIcon.icon (done with the app-icon skill before M1)
- States: Default, Dark, Tinted, Clear looks
- Words: none
- Access: none
Status: done

## Coverage

| Screen | Story |
| --- | --- |
| 01-status-item.png | S-002, S-023 |
| 02-popover-default.png | S-003, S-004, S-005, S-011 |
| 03-gear-menu.png | S-008, S-013 |
| 04-bar-hover-used.png | S-004 |
| 05-help-details.png | S-021 |
| 06-help-hogs.png | S-021 |
| 07-prefs-general.png | S-023, S-024, S-025 |
| 08-prefs-text-menu.png | S-023 |
| 09-prefs-text-size-menu.png | S-023 |
| 10-prefs-advanced.png | S-009, S-014, S-016 |
| 11-prefs-extras.png | Dropped |
| 12-prefs-about.png | S-026 |
| Licensing sheet | Dropped |

Research "Version one: yes" rows: readout S-002/S-023, breakdown S-004,
pressure S-002/S-003, history S-020, top apps S-005, quit/force quit
S-006/S-007, one-click clean S-011, auto-clean S-014, clean after quit S-015,
notifications S-017, freed feedback S-012, global hotkey S-018, launch at
login S-024, own CPU/RAM S-022.

## Dropped

- Unlock Extreme button and Extreme Clean (upsell; allocate-and-touch harms other apps).
- Extras pane: carry over Mac App Store purchases (vendor licensing).
- Licensing sheet and license deactivation (no licensing).
- Hide Unlock Extreme Button setting (no upsell to hide).
- Show icon in dock (menu bar app; Settings window is enough).
- Customer Support, Check for Updates, Join Mailing List menu items (vendor).
- FAQ / Fan Page / Twitter / website links in About (vendor).
- Threshold in MB that turns text red (replaced by pressure levels).

## Later

- Idle-app timer that quits apps on its own.
- CPU, disk, and network monitoring.
- Themes, compact mode, more menu bar widget styles.
- iCloud sync of settings.
