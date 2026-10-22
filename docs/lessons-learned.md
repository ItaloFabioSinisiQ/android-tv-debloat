# Lessons learned

Pitfalls and negative results from two sessions on a TCL 65C6K (Android 14, 2.4 GB RAM) on 2026-10-20 and 2026-10-21. Each one cost time or produced a wrong conclusion at first.

## Summary

| # | Lesson | Impact |
|---|--------|--------|
| 1 | The firmware silently re-enabled disabled packages at boot | A "gain" was wrongly attributed to debloating |
| 2 | A reboot is the biggest single improvement | MemAvailable 528 → 1031 MB |
| 3 | Full AOT compilation made apps slower | +11% to +38% cold-start time |
| 4 | Load average of 16 to 21 is not CPU load | CPU was ~88% idle |
| 5 | Measure before changing anything | Session 1 had no baseline |
| 6 | Voice search costs CPU even with the Assistant off | ~15 to 25% of one core |
| 7 | Some debug commands are not harmless | `audioserver` restarted once |
| 8 | Shell loops around `adb shell` silently skip items | Only the first package processed |
| 9 | Third-party debloat scripts are not tuning | Lists only, no measurement |
| 10 | Some "optimizations" trade away features or speed | Apps-only mode, process limit, launcher swap |

## 1. Disabled packages came back after a reboot

On 2026-10-21, 13 packages were disabled with `pm disable-user --user 0`. After a reboot, all 13 were enabled again, with state reset to default (`enabled=0` in `dumpsys package`). The 16 packages disabled the day before stayed disabled. Something in the vendor boot path resets selected packages.

The fix was `pm uninstall -k --user 0`, which survived the next reboot. The APKs stay on the system partition and come back with `cmd package install-existing --user 0 <pkg>`.

**Rule:** after every reboot, compare `pm list packages -d` and `pm list packages` against your revert lists before measuring.

## 2. The reboot, not the packages, produced the gain

The before/after comparison for those 13 packages looked like a success:

| Metric | Before (up for days) | After (4 min after reboot) |
|--------|---------------------|----------------------------|
| MemAvailable | 528 MB | 1031 MB (825 MB with 4 streaming apps open) |
| Swap (zram) used | 96% | 44% (75% with 4 apps open) |

| App, cold start ms (run 1 / 2 / 3) | Before | After |
|------------------------------------|--------|-------|
| Netflix | 1146 / 484 / 477 | 643 / 481 / 410 |
| YouTube | 1000 / 609 / 623 | 859 / 602 / 482 |
| Max | 1051 / 763 / 616 | 1061 / 535 / 549 |
| Prime Video | 940 / 644 / 602 | 890 / 555 / 570 |

But at the time of the "after" measurement the 13 packages were already re-enabled (lesson 1). The whole improvement came from rebooting a TV that had not been restarted for days.

**Rules:**

- Reboot and wait a fixed time before the baseline, and do the same before every later measurement.
- Report what actually changed between the two measurements. If it was a reboot plus packages, say so.
- Rebooting about once a week is the cheapest tuning available on a low-RAM TV.

## 3. Full AOT compilation (`speed`) made cold starts slower

`cmd package compile -m speed -f` was run for four apps. Average of three cold starts:

| App | Default `speed-profile` (ms) | Full `speed` (ms) | Change |
|-----|------------------------------|-------------------|--------|
| Netflix | 557 | 674 | +21% |
| YouTube | 621 | 856 | +38% |
| Max | 821 | 1075 | +31% |
| Prime Video | 696 | 774 | +11% |

Fully compiled code is much larger. On a TV with little free RAM, loading it from storage costs more than the JIT work it saves. Reverted with `cmd package compile -m speed-profile -f <pkg>`.

## 4. The load average lies on MediaTek TVs

`uptime` showed a load average of 16 to 21 on a 4-core CPU. `/proc/stat` and `top` showed the CPU about 88% idle, at 63 °C, with all cores at their 1.39 GHz maximum and no throttling.

The load came from 16 MediaTek kernel threads (HDMI Rx, HDMI eARC, panel, DRAM, SPDIF, GPIO polling) that sit in uninterruptible sleep (`D` state) permanently, which Linux counts as load. Do not tune anything based on load average on these TVs.

## 5. Measure before the first change

Session 1 applied DNS, animations, screensaver and 16 package changes before any measurement, so its effect cannot be quantified. Session 2 measured first, which is the only reason lesson 2 was discovered.

Other measurement pitfalls:

- `dumpsys meminfo` times out on this TV; use `dumpsys -t 60 meminfo`.
- Cold-start run 1 is consistently slower than runs 2 and 3 because the page cache still holds app files after `force-stop`. Report all runs.
- `am start -W` needs the exact launcher component. Resolve it with `cmd package resolve-activity --brief -c android.intent.category.LEANBACK_LAUNCHER <pkg>`; TV apps often have no regular `LAUNCHER` activity.

## 6. Voice search keeps the mic busy

With hands-free "Ok Google" already off (`hotword_detection_enabled=0`, Assistant toggle off), `com.google.android.katniss:interactor` still used about 15 to 25% of one core, in an audio-input thread reading the built-in microphone.

What was tried, all reverted:

| Attempt | Result |
|---------|--------|
| `settings put global tcl_app_settings_micro_phone false` | No effect, even after reboot |
| `appops set com.google.android.katniss RECORD_AUDIO_HOTWORD ignore` | `silenced:true`, but CPU use unchanged, even after force-stop |
| Global microphone privacy toggle | Not tried: likely disables the remote's voice search too, which uses `RECORD_AUDIO` |

The CPU cost is the price of keeping voice search. CPU was not the bottleneck anyway (lesson 4).

## 7. Some read-only commands are not harmless

Piping `dumpsys media.audio_flinger` into `head` closed the pipe early, and `audioserver` restarted. Audio recovered on its own. Redirect that output to a file instead of truncating it.

## 8. `adb shell` inside a loop eats the loop's input

```sh
while read -r p; do adb shell pm enable "$p"; done < list.txt   # processes only the first line
while read -r p; do adb shell -n pm enable "$p"; done < list.txt  # correct
```

Also, in zsh, do not name a loop variable `path`: it is tied to `PATH`, and overwriting it breaks command lookup for the rest of the session.

## 9. Community debloat repos are lists, not tuning

The [cleanyourtv](https://github.com/Gathin23/cleanyourtv) repository was reviewed. It contained disable lists and a launcher swap, with no performance measurement or tuning. Its package names for the same board were useful as a reference, and its do-not-touch notes (Wi-Fi, HDMI, remote mic) matched what this guide lists. Its scripts were not run.

**Rule:** read such lists, cross-check each package on your own TV, and apply changes yourself in small batches. Do not run scripts you have not read.

## 10. "Optimizations" that cost features or speed

| Idea | Outcome |
|------|---------|
| Background process limit | Declined: forces more cold starts on a TV that already has too few warm ones |
| Apps-only mode | Rejected: the TV warns that it also disables Search and voice search |
| Projectivy launcher | Home opened faster (78 ms vs 132 ms), but no difference in daily use; it used 80 to 100 MB RAM and about 30% of one core idle (animated background). Uninstalled |
| Disabling `com.tcl.gamebar` | Done by mistake; it handles the console game bar and HDMI game-mode events. Re-enabled |

## Bottom line

On a 2.4 GB TV, RAM is the hard limit. The best return comes from:

1. Rebooting about once a week.
2. Removing bloat that stays resident in memory.
3. An ad-blocking Private DNS.

The real fix is an external streaming device with 4 GB of RAM or more, with the TV used only as a display.
