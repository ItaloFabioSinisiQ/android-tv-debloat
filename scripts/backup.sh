#!/bin/sh
# Read-only snapshot of package state and settings. Run it BEFORE any change.
# Nothing on the TV is modified.
set -eu

usage() {
  echo "usage: backup.sh SERIAL [OUT_DIR]" >&2
  echo "  SERIAL   adb serial, e.g. <TV_IP>:<PORT> (see 'adb devices')" >&2
  echo "  OUT_DIR  default: ./backup-YYYYMMDD-HHMMSS" >&2
  exit 2
}

case "${1:-}" in ''|-h|--help) usage ;; esac
SERIAL=$1
OUT=${2:-backup-$(date +%Y%m%d-%H%M%S)}
ADB=${ADB:-adb}

sh_() { "$ADB" -s "$SERIAL" shell -n "$@" | tr -d '\r'; }
pkgs() { sh_ pm list packages "$@" | sed 's/^package://' | sort; }

"$ADB" -s "$SERIAL" get-state >/dev/null || { echo "device $SERIAL not reachable" >&2; exit 1; }
mkdir -p "$OUT"
cd "$OUT"

pkgs           > packages_all.txt
pkgs -s        > packages_system.txt
pkgs -3        > packages_user.txt
pkgs -d        > packages_disabled.txt
pkgs -u        > packages_all_including_uninstalled.txt
# Packages present on the system image but removed for user 0
comm -13 packages_all.txt packages_all_including_uninstalled.txt > packages_uninstalled_for_user.txt

for ns in global secure system; do
  sh_ settings list "$ns" | sort > "settings_$ns.txt"
done

{
  for k in window_animation_scale transition_animation_scale animator_duration_scale \
           private_dns_mode private_dns_specifier; do
    echo "global $k=$(sh_ settings get global "$k")"
  done
  for k in screensaver_enabled screensaver_activate_on_sleep screensaver_activate_on_dock \
           hotword_detection_enabled; do
    echo "secure $k=$(sh_ settings get secure "$k")"
  done
} > settings_of_interest.txt

sh_ getprop > getprop.txt
{
  echo "android=$(sh_ getprop ro.build.version.release)"
  echo "model=$(sh_ getprop ro.product.model)"
  echo "product=$(sh_ getprop ro.product.name)"
  echo "board=$(sh_ getprop ro.product.board)"
  echo "build=$(sh_ getprop ro.build.fingerprint)"
} > device.txt

sh_ cat /proc/meminfo > meminfo.txt
sh_ uptime > uptime.txt

echo "Snapshot written to $(pwd)"
wc -l packages_*.txt
