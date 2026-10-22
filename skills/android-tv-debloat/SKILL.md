---
name: android-tv-debloat
description: "Trigger: Android TV, Google TV, debloat, slow TV, adb TV, disable TV apps, TV ads, TCL. Safely debloat and tune a low-RAM Android TV over ADB with backup, measurement and revert."
license: MIT
metadata:
  author: "Italo Sinisi"
  version: "1.0"
---

## Activation Contract

Use when a human wants to speed up, debloat, remove ads from, or diagnose an Android TV / Google TV over ADB. Do not use for phones, rooted devices, or flashing firmware.

## Hard Rules

- Ask the human before EVERY state-changing command (`pm disable-user|uninstall|enable`, `cmd package install-existing|compile`, `settings put`, `appops set`, `am force-stop`, `reboot`, script `--apply`). Show the exact command and its revert. One approval covers one batch only.
- Read-only commands (`pm list`, `settings get|list`, `getprop`, `dumpsys`, `cat /proc/*`, `top`, `ps`) are allowed without asking.
- Back up (package lists, settings values) and measure a baseline BEFORE the first change.
- One batch at a time, then reboot, wait the same fixed time as the baseline, re-measure, verify.
- NEVER touch the do-not-touch list in `references/packages-tcl-g08.md`; treat unknown vendor packages as unknown, not as bloat.
- Append every change to `disabled_by_us.txt` or `uninstalled_by_us.txt`; record every changed setting with its previous value.
- If a firmware re-enables disabled packages at boot, use `pm uninstall -k --user 0` and verify after the next reboot.
- Use `adb shell -n` inside loops. Use `dumpsys -t 60 meminfo`. Never pipe `dumpsys media.audio_flinger` into `head`; redirect it to a file.
- Do not run scripts from third-party debloat repos; read their lists and apply changes yourself.
- Describe `disable-user` and `uninstall -k --user 0` accurately: neither removes the system APK or frees storage; both are reversible.
- When finished, ask the human to turn off Wireless debugging.

## Decision Gates

| Situation | Action |
|-----------|--------|
| Package in do-not-touch list | Refuse; explain the consequence |
| Package not in reference, vendor-specific | Explain uncertainty; ask; prefer `disable-user` first |
| Package re-enabled after reboot | Switch it to `pm uninstall -k --user 0` (ask first) |
| HDMI, Wi-Fi, voice or casting broke | Stop; propose reverting the last batch now (ask, then run) |
| Human asks for full AOT `speed` compile or process limit | Warn: measured slower on low RAM; ask |
| Baseline taken on a long-uptime TV | Say gains may be from the reboot; re-baseline after reboot |

## Execution Steps

1. Confirm `adb` works; guide pairing (`adb pair`) and `adb connect` via `adb mdns services`.
2. Snapshot: `scripts/backup.sh SERIAL` when the repo scripts are available, else the commands in `references/commands.md`.
3. Reboot (ask), wait, baseline: `scripts/measure.sh SERIAL`.
4. Propose one batch (table: package, purpose, loss, risk, revert). Wait for approval.
5. Apply, record, reboot (ask), re-measure, verify package state and features.
6. Repeat or stop. Offer `scripts/revert.sh SERIAL` at any point.

## Output Contract

Report per batch: commands run, packages and settings changed, before/after tables (MemAvailable, swap %, cold starts per run), verification results, and revert list paths. Attribute gains honestly: separate reboot, package and setting effects; state when a measurement cannot isolate a cause; report negative results.

## References

- `references/commands.md` - command cheatsheet: connect, backup, measure, change, verify, revert.
- `references/packages-tcl-g08.md` - TCL G08 package table and do-not-touch list.
