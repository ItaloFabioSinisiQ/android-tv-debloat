# Command cheatsheet

`S` = adb serial (`<TV_IP>:<PORT>`). Prefix every command with `adb -s "$S" shell` unless shown otherwise. Inside loops use `adb -s "$S" shell -n`.

Legend: **RO** = read-only, run freely. **ASK** = state-changing, ask the human first and record the revert.

## Connect

| Kind | Command |
|------|---------|
| RO | TV: Settings › System › About › "Android TV OS build" ×7, then Developer options › Wireless debugging |
| ASK | `adb pair <TV_IP>:<PAIRING_PORT> <CODE>` (once; the human reads the code on the TV) |
| RO | `adb mdns check` ; `adb mdns services` (look for `_adb-tls-connect`) |
| RO | `adb connect <TV_IP>:<PORT>` ; `adb devices -l` (port changes after each reboot) |

## Backup (RO)

```sh
pm list packages    | sed 's/package://' | sort   # all for user 0
pm list packages -s ; pm list packages -3          # system ; third-party
pm list packages -d                                # disabled
pm list packages -u                                # includes uninstalled-for-user
settings list global ; settings list secure ; settings list system
settings get global window_animation_scale         # also transition_/animator_duration_scale
settings get global private_dns_mode ; settings get global private_dns_specifier
settings get secure screensaver_enabled
getprop ro.build.version.release ; getprop ro.product.model ; getprop ro.product.board
```

## Measure (RO, except force-stop/launch which interrupt viewing: ASK once)

```sh
cat /proc/meminfo                                  # MemAvailable, SwapTotal, SwapFree
dumpsys -t 60 meminfo                              # never plain dumpsys meminfo (times out)
uptime                                             # record uptime with every measurement
top -b -n 1 -m 10 ; cat /proc/stat                 # real CPU use; ignore load average on MediaTek
cmd package resolve-activity --brief -a android.intent.action.MAIN \
  -c android.intent.category.LEANBACK_LAUNCHER <pkg> # last line = component
am force-stop <pkg> ; am start -W -n <component>   # TotalTime = ms to first frame; 3 runs
input keyevent KEYCODE_HOME
dumpsys wifi | grep -m1 -i frequency               # actual band, regardless of SSID name
dumpsys media.audio_flinger > file.txt             # never pipe into head
```

## Change (ASK) and revert

| Change | Command | Revert |
|--------|---------|--------|
| Disable package | `pm disable-user --user 0 <pkg>` | `pm enable --user 0 <pkg>` |
| Remove for user 0 (keeps APK and data) | `pm uninstall -k --user 0 <pkg>` | `cmd package install-existing --user 0 <pkg>` |
| Remove third-party app for user 0 | `pm uninstall --user 0 <pkg>` | Reinstall from Play Store |
| Ad-blocking DNS | `settings put global private_dns_mode hostname` ; `settings put global private_dns_specifier dns.adguard-dns.com` | `settings put global private_dns_mode off` |
| Animations off | `settings put global window_animation_scale 0` (and `transition_animation_scale`, `animator_duration_scale`) | same with the backed-up value (usually `1`) |
| Screensaver off | `settings put secure screensaver_enabled 0` | `settings put secure screensaver_enabled 1` |
| Reboot | `adb -s "$S" reboot` | n/a |
| Undo a `speed` compile | `cmd package compile -m speed-profile -f <pkg>` | n/a |

Do not propose `cmd package compile -m speed -f`: measured 11 to 38% slower cold starts on 2.4 GB RAM.

Long-press with the remote emulated: `input swipe <x> <y> <x> <y> 1500`.

## Verify after every reboot (RO)

```sh
pm list packages -d | wc -l                        # equals the disabled count
while read -r p; do adb -s "$S" shell -n pm list packages | grep -qx "package:$p" && echo "BACK: $p"; done < uninstalled_by_us.txt
dumpsys package <pkg> | grep -o ' enabled=[0-9]'   # 0 default (re-enabled), 3 disabled-user
```

Then ask the human to test: every HDMI input, console game mode, Wi-Fi after reboot, remote voice button, voice search, casting, quick settings panel, system update screen.

## Revert everything (ASK)

```sh
while IFS= read -r p; do adb -s "$S" shell -n cmd package install-existing --user 0 "$p"; done < uninstalled_by_us.txt
while IFS= read -r p; do adb -s "$S" shell -n pm enable --user 0 "$p"; done < disabled_by_us.txt
adb -s "$S" reboot
```

## Shell pitfalls

- `adb shell` without `-n` inside `while read` consumes stdin: only the first item runs.
- In zsh, never name a variable `path` (it is tied to `PATH`).
- `adb connect` exits 0 even when it fails; check for `connected to` in the output.
