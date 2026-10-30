# MangoCleaner glossary

One name per thing. Buttons, menus, tooltips, notifications, and VoiceOver
use these words only.

## Things

| Term | Means | Not |
| --- | --- | --- |
| Menu bar item | The glyph and text MangoCleaner shows in the menu bar | status item, widget, icon |
| Memory window | The window that drops down from the menu bar item | popover, panel, dashboard |
| Memory pressure | How hard macOS works to find memory, as a level and a percent | memory load, RAM usage, health |
| Normal / High / Critical | The three pressure levels (green, yellow, red) | OK, warning, tight, danger, low/high memory |
| Available | Free plus file cache: what apps can get without compressing or swapping. The menu bar item shows it | free (in the menu bar), usable |
| Free | Memory nothing uses right now | unused |
| App memory | Memory apps and their processes use | app RAM, active |
| Wired | Memory macOS keeps for itself and can't compress | system, kernel |
| Compressed | Memory macOS squeezed to make room | zipped |
| File cache | Recently used files kept in memory; macOS frees it when needed | cached files, inactive, purgeable |
| Swap | Memory written to disk because RAM ran out | virtual memory, page file |
| Total | RAM installed in this Mac | physical memory, installed |
| Top apps | The five apps using the most memory | memory hogs, processes, offenders |
| Helper | The small background part that clears the file cache with admin rights | daemon, privileged tool, service |
| Login Items | The System Settings page where the helper is turned on (macOS's own name) | background items, startup items |
| Refresh interval | How often the numbers update | polling rate, update frequency |

## Actions

| Term | Means | Not |
| --- | --- | --- |
| Quit | Ask an app to close normally; it can save first | close, kill, end |
| Force Quit | Close an app at once; unsaved work is lost | kill, terminate |
| Clear File Cache | Run `purge` through the helper to empty the file cache | clean, free up, optimize, boost |
| Allow Helper… | Register the helper; macOS then asks for approval in Login Items | install, enable, authorize |
| Automation | The Settings tab for Clear automatically | Advanced, auto |
| Notifications | The Settings tab for alerts when pressure rises | alerts, warnings |
| Memory window shortcut | The keys that open and close the memory window from any app (⌃⌥M) | hotkey, global key |
| Keep Window Open | Float the memory window outside the menu bar, on every Space | pin, detach |
| Return to Menu Bar | Close the floating window; the memory window drops down from the menu bar item again | unpin, reset window position |
| Menu bar shows | What the menu bar item shows next to its glyph: Available memory, Pressure %, or Icon only | status text |
| Open at login | Start MangoCleaner when you log in | launch at login, start at login |
| Clear automatically | Clear File Cache on its own when pressure stays high or a big app quits | auto clean, smart clean |
| Settings… | Open the Settings window (⌘,) | Preferences, options |
| About MangoCleaner | Open the About window | info |
| Quit MangoCleaner | Quit this app (⌘Q) | exit |
