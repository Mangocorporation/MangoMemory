# Memory cleaners and monitors

Research for MangoCleaner. Done 2026-10-29.
[V] verified in a source, [K] from knowledge, [U] unverified, test first.

Question: what makes the best Memory Clean 2–style memory app on the Mac in 2026?
Decision it informs: version-one features, distribution (Mac App Store vs Developer ID), and what "clean" honestly does.

Reference app: Memory Clean 2 (FIPLAB), installed at `/Applications/Memory Clean 2.app`.

## Findings

### Market
- Memory Clean 2 is legacy: FIPLAB calls it the "predecessor to Memory Meter 3", free, direct download, auto-frees when free memory drops below a threshold [V](https://fiplab.com/apps/memory-clean-for-mac). Listed as Intel-only / Rosetta [U](https://rosettacheck.com/apps/com.fiplab.memoryclean2).
- Memory Clean 3 is now Memory Meter 3: direct only, trial, Deep Refresh, Memory Hogs list, inactive-app Smart Alerts, compact/detailed view, themes [V](https://fiplab.com/apps/memory-clean-3-for-mac). FIPLAB left the Mac App Store in 2018 [V](https://blog.fiplab.com/transition-to-memory-clean-3-direct-version).
- Memory Diag: free, Mac App Store, top apps by memory, pressure meter with alerts; Tahoe fix Sep 2025 [V](https://apps.apple.com/app/memory-diag/id748212890).
- iStat Menus 7.5: paid direct, Setapp, and Mac App Store; memory history, pressure, compressed, swap, top apps; no freeing [V](https://bjango.com/mac/istatmenus/).
- Stats (exelban): free, MIT, 10 RAM widget styles, pressure dot, top processes, notifications for RAM %, free, pressure, swap; no freeing [V](https://github.com/exelban/stats).
- CleanMyMac menu: free RAM, pressure, swap, top apps, one-click "Free Up" ("Optimize" in the Mac App Store edition); no documented auto-free [V](https://macpaw.com/support/cleanmymac/knowledgebase/check-and-free-ram).
- MenuMeters: free, open source, pressure mode matches Activity Monitor [V](https://github.com/yujitach/MenuMeters/releases).
- Gap: only FIPLAB offers threshold auto-clean, and its maintenance is unclear; no maintained app combines honest pressure-first monitoring, app-level action, and automation [V]/[U].

### Platform
- RAM breakdown: `host_statistics64(HOST_VM_INFO64)` × `vm_page_size`; total from `host_info(HOST_BASIC_INFO).max_mem`. Stats formulas: used = active + inactive + speculative + wired + compressed − purgeable − external; app = used − wired − compressed; cache = purgeable + external [V](https://raw.githubusercontent.com/exelban/stats/master/Modules/RAM/readers.swift).
- Activity Monitor's exact formula is unpublished; naive sums are off by about 0.6 GB on M1 [V](https://developer.apple.com/forums/thread/702498). Validate against Activity Monitor on macOS 26 [U].
- Pressure: `sysctlbyname("kern.memorystatus_vm_pressure_level")` 1/2/4 = normal/warn/critical [V](https://chromium.googlesource.com/chromium/src/+/706d93d0d/base/memory/memory_pressure_monitor_mac.cc). `kern.memorystatus_level` gives 0–100 % available for a smoother gauge [V](https://mole.fit/blog/mac-memory-pressure-explained.md).
- Swap: `sysctlbyname("vm.swapusage")` → `xsw_usage` [V](https://raw.githubusercontent.com/exelban/stats/master/Modules/RAM/readers.swift).
- Top processes: Apple DTS recommends `proc_pid_rusage` (`ri_phys_footprint`) [V](https://developer.apple.com/forums/thread/769021). Whether it works on other processes inside the sandbox is unknown [U]. Stats shells out to `top`.
- Quit other apps: `NSRunningApplication.terminate()` returns false in the sandbox [V](https://developer.apple.com/forums/thread/122020).
- `purge` needs root and only drops file cache [K]. Allocate-and-touch "cleaning" pushes other apps into compression and swap: cosmetic at best, harmful at worst [K]. `malloc_zone_pressure_relief` affects only our own process [K].
- Privileged work needs an `SMAppService.daemon` helper, Developer ID only, user approval in Login Items [K].
- `MenuBarExtra(.window)` plus `LSUIElement`, and `SMAppService.mainApp` launch at login, work sandboxed; login must be opt-in [K].
- App Review 2.3.1 / 1.1.6 ban misleading claims and inaccurate device data; 2.4.5 requires sandbox and no root escalation [V](https://developer.apple.com/app-store/review/guidelines/).

### Is "freeing RAM is pointless" fair?
- Fair: cached files make relaunches fast and stay until overwritten [V](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac); usage climbs straight back after a purge [V].
- Fair: memory pressure is the number that matters; yellow means compressing, red means heavy swap [V](https://macmost.com/memory-pressure-and-how-your-mac-uses-memory.html).
- Fair: a leaking app's memory only returns when you quit it [V](https://talk.macpowerusers.com/t/alternative-to-clean-my-mac-or-do-i-need-it-at-all/18806).
- Overstated: tight 8 GB Macs and leaky apps are real; users value seeing which app to quit [V](https://apps.apple.com/app/memory-diag/id748212890).

## Likes and dislikes

| App | People like | People dislike | Sources |
| --- | --- | --- | --- |
| Memory Clean 2 | Simple and free; one click from the menu bar; visibly frees memory after heavy apps (about 700 MB); popular, Apple featured | "Doesn't do more than `sudo purge`"; older Macs slow during clean; Intel-only and abandoned; sometimes needs several runs; preferences hidden on right-click | [macworld](https://www.macworld.com/article/220765/mac-gems-free-up-your-macs-ram-with-memory-clean.html), [waerfa](https://waerfa.com/memory-clean-2-free-up-memory), [rosettacheck](https://rosettacheck.com/apps/com.fiplab.memoryclean2) |
| Memory Clean 3 / Memory Meter 3 | Spots inactive apps; auto-cleans after a memory hog quits; compact mode and dark theme; Apple silicon native | Developer says it only helps after closing a heavy app; no independent reviews; paid extras | [waerfa](https://waerfa.com/memory-clean-3-free-up-memory), [softpedia](https://mac.softpedia.com/progChangelog/Memory-Clean-Changelog-105893.html), [clubic](https://clubic.com/telecharger-fiche436171-memory-clean-3.html) |
| Memory Diag | Live list of apps by memory helps find hogs; color-coded meter; wired/app/cache/compressed breakdown; still updated for Tahoe | Rating prompt at shutdown; showed wrong RAM after boot-drive switch; no auto-clean; gains short-lived | [App Store](https://apps.apple.com/app/memory-diag/id748212890), [softpedia](https://mac.softpedia.com/get/Utilities/Memory-Diag.shtml) |
| CleanMyMac menu | Live pressure, red only when action is needed (vendor claim); free up from the alert; general maintenance | False "out of memory" alerts on a 16 GB M1 with only Safari open; nagging alerts; weekly upsells; called useless or malware | [MacRumors](https://forums.macrumors.com/threads/why-does-cleanmymac-keep-saying-m1-out-of-memory.2378515/), [MPU](https://talk.macpowerusers.com/t/how-to-troubleshoot-ram-maxing-out/25496) |
| iStat Menus | Polish; light on CPU (v7 claims 80 % less); very configurable; top apps, pressure, swap | Breaks on new macOS or chips until updated; features moved to subscription; menu bar crowding on notched Macs; v7 harder to set up | [MacRumors](https://forums.macrumors.com/threads/istats-menu-vs-stats-which-is-better-battery-consumption.2354863/), [Setapp](https://setapp.com/apps/istat-menus/customer-reviews), [mjtsai](https://mjtsai.com/blog/2024/08/01/istat-menus-7) |
| Stats | Free, open source; many modules; memory at a glance; per-module settings | Its own CPU and energy use; own RAM use and a leak; pressure colors wrong; RAM counter bug on macOS 26; requests for pressure % chart and top-processes view | [GitHub](https://github.com/exelban/stats), [issues](https://github.com/exelban/stats/issues) |
| MenuMeters | Best free iStat alternative; pie/bar/graph; pressure matches Activity Monitor; lightweight | Stalled releases; Apple silicon memory bugs; requests for %, GB, separate used/free; animation loads WindowServer | [GitHub issues](https://github.com/yujitach/MenuMeters/issues), [taoofmac](https://taoofmac.com/space/apps/menumeters) |
| App Tamer | Slows runaway apps; battery life; shows memory hogs; one-time price | Helper uses more CPU than the apps it watches; crashes; slows the active app; vague advice | [Setapp](https://setapp.com/apps/app-tamer/customer-reviews), [vendor](https://www.stclairsoft.com/AppTamer/) |

Patterns:
- Must have (liked across apps): one-click action from the menu bar; a live list of the apps using the most memory; pressure, compressed and swap breakdown; color that tells you at a glance; a light footprint.
- Our chance (disliked across apps): the monitor's own CPU and RAM use; false or nagging alerts and upsells; wrong numbers vs Activity Monitor; breaking on new macOS; dishonest "clean" claims; settings hidden on right-click; features moved to a subscription.

## Feature matrix

| Feature | Memory Clean 2 | Memory Clean 3 | Memory Diag | iStat Menus | Stats | CleanMyMac menu | Version one? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Menu bar readout (%, GB, pressure color) | Free MB | Yes | Color meter | Yes, many styles | 10 widgets | Yes | Yes |
| Breakdown app/wired/compressed/cache/swap | Partial | Yes | Yes | Yes | Yes | Partial | Yes |
| Memory pressure | No | No | Yes | Yes | Yes | Yes | Yes, as headline |
| History graph | No | No | No | Yes | Yes | No | Yes, short (last hour) |
| Top apps by memory | No | Yes | Yes | Yes | Yes | Yes | Yes |
| Quit / force quit from list | No | Inactive apps | No | Yes | No | No | Yes |
| One-click clean (purge file cache) | Yes | Yes | Yes | No | No | Yes | Yes, labeled honestly, needs helper |
| Extreme / deep clean | IAP | Yes | No | No | No | No | No |
| Auto-clean on threshold | Free memory | After hog quits | No | No | No | No | Yes, pressure-based |
| Clean after heavy app quits | No | Yes | No | No | No | No | Yes |
| Notifications on pressure or swap | No | Inactive apps | Yes | Rules | Yes | Yes (nagging) | Yes, quiet by default |
| Freed-amount feedback | Yes | Yes | No | n/a | n/a | Yes | Yes, before and after |
| Global hotkey | No | No | No | Yes | Yes | No | Yes |
| Launch at login | Yes | Yes | Yes | Yes | Yes | Yes | Yes, opt-in |
| Own CPU/RAM shown | No | No | No | No | No | No | Yes |
| Themes / compact mode | No | Yes | No | Colors | Colors | No | No (system light/dark only) |
| Idle-app timer that quits apps | No | Yes | No | No | No | No | No |

## Decisions
1. Distribute direct with Developer ID, notarized, not sandboxed, because the sandbox blocks quitting other apps [V](https://developer.apple.com/forums/thread/122020) and `purge` needs root [K]; FIPLAB left the Mac App Store for the same reason [V](https://blog.fiplab.com/transition-to-memory-clean-3-direct-version).
2. Make memory pressure the headline and the menu bar color, with free/used as secondary, because pressure is what Apple and informed users trust [V](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac) and wrong alerts are CleanMyMac's top complaint [V](https://forums.macrumors.com/threads/why-does-cleanmymac-keep-saying-m1-out-of-memory.2378515/).
3. Use Stats' formulas for the breakdown [V](https://raw.githubusercontent.com/exelban/stats/master/Modules/RAM/readers.swift). Planned test: a self-test that compares our numbers with Activity Monitor and `vm_stat` on macOS 26, within 3 %.
4. The main action is "Quit this app" from the top-apps list, because quitting is the only thing that returns a leaking app's memory [V](https://talk.macpowerusers.com/t/alternative-to-clean-my-mac-or-do-i-need-it-at-all/18806) and the list is the most praised feature [V](https://apps.apple.com/app/memory-diag/id748212890).
5. Keep the big Clean button (Memory Clean 2's signature), but it runs `purge` through an `SMAppService.daemon` helper, is labeled "Clear file cache", and shows the before and after amount. Never allocate-and-touch. Because `purge` needs root [K] and allocate-and-touch harms other apps [K]. Planned test: probe script that measures pressure, free memory and swap before and after purge on macOS 26.
6. Auto-clean triggers on pressure (warn level held for N seconds) and after a heavy app quits, off by default, because threshold auto-clean is the market gap [V](https://fiplab.com/apps/memory-clean-for-mac) and MC3's after-quit clean is its best-liked idea [V](https://waerfa.com/memory-clean-3-free-up-memory).
7. No nags: no rating prompts, no upsells, alerts only at yellow or red, because these are the top dislikes of Memory Diag and CleanMyMac [V].
8. Stay light: refresh every 2 s by default (user can change), no animated menu bar graphics, show our own CPU and RAM in the popover, because monitor overhead is the top complaint across Stats, App Tamer and MenuMeters [V](https://github.com/exelban/stats/issues). Planned test: Instruments run under 0.5 % CPU and 40 MB RAM idle [U].
9. Popover order: pressure ring and headline, breakdown, short pressure history, top 5 apps with Quit, Clean button; Settings in a gear menu in the popover, because MC2's right-click preferences confuse people [V](https://www.macworld.com/article/220765/mac-gems-free-up-your-macs-ram-with-memory-clean.html) and Stats' popup order works [V](https://github.com/exelban/stats).
10. Apple silicon native, macOS 26 and later, one-time price or free, because iStat Menus and Stats lose goodwill when they break on new macOS or move features to a subscription [V](https://setapp.com/apps/istat-menus/customer-reviews).

## Open questions
- Does `proc_pid_rusage` read other users' and root processes' footprint without root? Test: a probe that lists the top 10 by `ri_phys_footprint` and compares with Activity Monitor [U].
- How much does `purge` actually change pressure and swap on Apple silicon macOS 26? Test: probe script before and after [U].
- Does `kern.memorystatus_vm_pressure_level` stay "normal" during heavy swapping? Test: a memory stress run while logging the level and swap [U].
- Does our breakdown match Activity Monitor on macOS 26 (the about 0.6 GB M1 gap)? Test: self-test comparison [U].
- How does Memory Clean 2 actually free memory and what does it report? Test: clone it (installed here) and watch `vm_stat` during a clean [U].
