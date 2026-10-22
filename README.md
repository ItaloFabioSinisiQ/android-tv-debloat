# Android TV debloat

A measured, reversible way to make a low-RAM Google TV / Android TV faster and quieter over ADB, without root. It includes a step-by-step guide, helper scripts, and an AI-agent skill that applies the same rules.

It was built on a **TCL 65C6K** (Google TV, Android 14, TCL G08 board, MediaTek quad-core up to 1.39 GHz, 2.4 GB RAM, 917 MB zram), but the method applies to any Android TV that allows wireless debugging.

> [!WARNING]
> **Use at your own risk.** Vendor firmware differs between brands, boards and even firmware versions. A package that is safe to remove on one TV can break HDMI, Wi-Fi or voice search on another. Every change here is reversible without a factory reset, but only if you take the backup first and keep the revert lists. Nothing here is endorsed by TCL, Google or any vendor.

## Who this is for

- Developers and power users comfortable with a terminal and `adb`.
- People with a Google TV that feels slow, shows promotional overlays, or runs out of memory.
- AI-agent users who want an assistant to do this safely (see [the skill](#use-it-with-an-ai-agent)).

## Results on the reference TV

| Change | Effect observed |
|--------|-----------------|
| Reboot after days of uptime | MemAvailable 528 MB → 1031 MB, swap used 96% → 44% |
| Removing resident bloat (29 packages) | Less RAM pressure; persisted only after switching to `pm uninstall -k --user 0` for 13 of them |
| AdGuard Private DNS | Ad and tracker domains blocked system-wide (not YouTube or in-app ad tiers) |
| Animations set to 0 | Menus and transitions respond instantly (not measured separately) |
| Full AOT compile (`speed`) | **Slower**: Netflix 557 → 674 ms, YouTube 621 → 856 ms (reverted) |

Cold-start times in ms (runs 1 / 2 / 3), 2026-10-21, before and 4 minutes after a reboot:

| App | Before | After |
|-----|--------|-------|
| Netflix | 1146 / 484 / 477 | 643 / 481 / 410 |
| YouTube | 1000 / 609 / 623 | 859 / 602 / 482 |
| Max | 1051 / 763 / 616 | 1061 / 535 / 549 |
| Prime Video | 940 / 644 / 602 | 890 / 555 / 570 |

> [!IMPORTANT]
> Most of that gain came from the **reboot**, not from the packages: the firmware had silently re-enabled the 13 newly disabled packages at boot. See [lessons learned](docs/lessons-learned.md). RAM is the hard limit; the real fix for a 2.4 GB TV is an external streaming device with 4 GB of RAM or more.

## Quick start

Requirements: Android platform-tools (`adb`) on macOS, Linux or Windows (WSL or Git Bash for the scripts), and the computer and TV on the same network.

1. On the TV: **Settings › System › About**, press **Android TV OS build** 7 times. Then **Settings › System › Developer options** › turn on **Wireless debugging**.
2. Pair once and connect:

   ```sh
   adb pair <TV_IP>:<PAIRING_PORT> <SIX_DIGIT_CODE>
   scripts/connect.sh            # finds the TV via mDNS and connects
   ```

3. Back up and measure **before** changing anything:

   ```sh
   scripts/backup.sh  <TV_IP>:<PORT>
   scripts/measure.sh <TV_IP>:<PORT>
   ```

4. Review [the package reference](docs/packages-tcl-g08.md), then preview a batch (dry run is the default):

   ```sh
   scripts/debloat.sh <TV_IP>:<PORT> scripts/lists/tcl-g08-disable.txt --method disable
   ```

5. Apply with `--apply`, reboot, re-measure, and check that every package stayed in the state you set.
6. Undo everything at any time:

   ```sh
   scripts/revert.sh <TV_IP>:<PORT>
   ```

7. Turn **Wireless debugging** off when you are done.

The full explanation, including why each step exists, is in the [guide](docs/guide.md).

## Documentation

| Document | Contents |
|----------|----------|
| [Guide](docs/guide.md) | Concepts, setup, backup, measurement, changes, verification, revert |
| [TCL G08 package reference](docs/packages-tcl-g08.md) | Every package touched, what you lose, risk, and the do-not-touch list |
| [Lessons learned](docs/lessons-learned.md) | Pitfalls and negative results, with numbers |
| [Scripts](scripts/) | `connect.sh`, `backup.sh`, `measure.sh`, `debloat.sh`, `revert.sh`, example lists |

## Use it with an AI agent

[`skills/android-tv-debloat/`](skills/android-tv-debloat/SKILL.md) is an agent skill that encodes the same workflow and safety rules: ask before every state-changing command, back up and measure first, one batch at a time, never touch the critical packages, and report gains honestly.

Install it by copying the folder into your agent's skill directory:

```sh
# Claude Code (user-wide)
cp -R skills/android-tv-debloat ~/.claude/skills/

# Claude Code (this project only)
mkdir -p .claude/skills && cp -R skills/android-tv-debloat .claude/skills/
```

Other agents that support the `SKILL.md` format (for example OpenCode, Codex or Gemini CLI setups) load skills from their own directories; copy the same folder there. Agents without skill support can be given `SKILL.md` as plain instructions.

## License

[MIT](LICENSE)
