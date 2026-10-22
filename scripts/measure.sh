#!/bin/sh
# Measure RAM and cold-start times. Non-persistent, but it force-stops and
# launches apps on the TV, so do not run it while someone is watching.
set -eu

usage() {
  cat >&2 <<'EOF'
usage: measure.sh SERIAL [PACKAGE ...]

  SERIAL   adb serial, e.g. <TV_IP>:<PORT>
  PACKAGE  apps to time; default: Netflix, YouTube, Max, Prime Video

Writes to ./measure-YYYYMMDD-HHMMSS/ (override with OUT_DIR=...).
Each app: force-stop, then `am start -W`, 3 runs (RUNS=...).
EOF
  exit 2
}

case "${1:-}" in ''|-h|--help) usage ;; esac
SERIAL=$1; shift
[ $# -gt 0 ] || set -- com.netflix.ninja com.google.android.youtube.tv \
  com.wbd.stream com.amazon.amazonvideo.livingroom
ADB=${ADB:-adb}
RUNS=${RUNS:-3}
OUT=${OUT_DIR:-measure-$(date +%Y%m%d-%H%M%S)}

sh_() { "$ADB" -s "$SERIAL" shell -n "$@" | tr -d '\r'; }

meminfo() {
  sh_ cat /proc/meminfo | awk '
    /^(MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree):/ { print; v[$1]=$2 }
    END {
      if (v["SwapTotal:"] > 0)
        printf "SwapUsedPct: %d%%\n", 100 * (v["SwapTotal:"] - v["SwapFree:"]) / v["SwapTotal:"]
      printf "MemAvailableMB: %d\n", v["MemAvailable:"] / 1024
    }'
}

"$ADB" -s "$SERIAL" get-state >/dev/null || { echo "device $SERIAL not reachable" >&2; exit 1; }
mkdir -p "$OUT"

sh_ uptime > "$OUT/uptime.txt"
meminfo | tee "$OUT/meminfo.txt"
# Plain `dumpsys meminfo` often times out on low-RAM TVs; raise the timeout.
sh_ dumpsys -t 60 meminfo > "$OUT/dumpsys_meminfo.txt" 2>&1 || echo "dumpsys meminfo failed" >&2

: > "$OUT/coldstart.txt"
for pkg in "$@"; do
  comp=$(sh_ cmd package resolve-activity --brief \
           -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER "$pkg" | tail -n 1)
  case "$comp" in
    */*) ;;
    *) echo "$pkg: no LEANBACK_LAUNCHER activity (not installed?), skipped" >&2; continue ;;
  esac
  times=""
  i=0
  while [ "$i" -lt "$RUNS" ]; do
    sh_ am force-stop "$pkg"
    sleep 2
    t=$(sh_ am start -W -n "$comp" | awk '/^TotalTime:/ {print $2}')
    times="$times ${t:-NA}"
    sleep 4
    sh_ input keyevent KEYCODE_HOME
    sleep 2
    i=$((i + 1))
  done
  echo "$pkg:$times" | tee -a "$OUT/coldstart.txt"
done

meminfo > "$OUT/meminfo_after_apps.txt"
echo "Results in $OUT/ (times in ms; run 1 is the coldest)"
