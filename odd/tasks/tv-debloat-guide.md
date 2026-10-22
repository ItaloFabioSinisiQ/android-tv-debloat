# Feature: Android TV debloat guide and agent skill

## Objective
Publish, for the developer community, a step-by-step guide and an AI-agent skill that reproduce the ADB-based debloat and performance tuning done on a low-RAM Google TV (TCL 65C6K, Android 14, MediaTek, 2.4 GB RAM).

## Problem / Why
The work was done interactively and lives in a private Obsidian note, local backups and agent memory. Others (humans and AI agents) cannot repeat it safely, and several lessons are non-obvious (firmware re-enables disabled packages, AOT compile made things slower, packages that break Wi-Fi or HDMI).

## Scope
- English guide: concepts, prerequisites, wireless ADB pairing, baseline measurement, changes, verification, revert, results, lessons and pitfalls.
- Agent skill (`SKILL.md`) usable by Claude Code and other agents: safety rules, workflow, commands, decision points.
- Generic helper scripts: connect, measure, revert.
- Scrub private data (IPs, SSIDs, emails, usernames, absolute home paths).

## Constraints
- Documentation and scripts only; no changes to the TV.
- No push, PR or publishing without explicit user approval.
- Artifacts in English, neutral tone.

## Tasks
- [x] T1 Guide, README and scripts (route: delegated writer; trigger: 2+ non-trivial files)
- [x] T2 Agent skill (route: delegated writer, same worker)
- [x] T3 Structural readback and privacy scan (route: inline)

## Verification evidence
- Writer: `sh -n scripts/*.sh` exit 0; `shellcheck -s sh` clean; `debloat.sh`/`revert.sh` exercised against a fake `adb`; relative links resolve.
- Parent spot check: `sh -n scripts/*.sh` OK; privacy `rg` (IPs, ports, SSID, emails, home paths, hostnames) returned nothing.
- Not run on a device: `resolve-activity -a android.settings.SYSTEM_UPDATE_SETTINGS` doc example, DNS `ping` check, `setupwraith` do-not-touch entry (marked "Not tested"). Mermaid not rendered.
- Docs and scripts only: no RED/GREEN test applies.

## Acceptance criteria
- A reader with a Mac/Linux/Windows PC and an Android TV can follow the guide end to end.
- Every change has a revert command.
- The skill encodes the safety rules and the ask-before-change policy.
- No personal data in the repo.

## Checks
- Passive docs: structural readback, links resolve, `sh -n` on scripts, `rg` privacy scan.

## Progress
- Branch `docs/tv-debloat-guide` created.
