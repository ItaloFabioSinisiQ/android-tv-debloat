#!/bin/sh
# Apply a package list. Dry-run by default; nothing changes without --apply.
# Every applied package is appended to the matching revert list.
set -u

usage() {
  cat >&2 <<'EOF'
usage: debloat.sh SERIAL LIST_FILE [--method disable|uninstall] [--record-dir DIR] [--apply]

  LIST_FILE   one package per line; blank lines and '#' comments ignored
  --method    disable   -> pm disable-user --user 0   (recorded in disabled_by_us.txt)
              uninstall -> pm uninstall -k --user 0   (recorded in uninstalled_by_us.txt)
              default: disable
  --record-dir  where the revert lists live (default: .)
  --apply     actually run the commands (default is a dry run)

Neither method deletes the system APK. Undo with scripts/revert.sh.
Packages in scripts/lists/do-not-touch.txt are always refused.
EOF
  exit 2
}

[ $# -ge 2 ] || usage
SERIAL=$1; LIST=$2; shift 2
METHOD=disable; RECORD_DIR=.; APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --method) [ $# -ge 2 ] || usage; METHOD=$2; shift 2 ;;
    --record-dir) [ $# -ge 2 ] || usage; RECORD_DIR=$2; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) usage ;;
  esac
done
ADB=${ADB:-adb}

case "$METHOD" in
  disable)   CMD="pm disable-user --user 0"; RECORD="$RECORD_DIR/disabled_by_us.txt" ;;
  uninstall) CMD="pm uninstall -k --user 0"; RECORD="$RECORD_DIR/uninstalled_by_us.txt" ;;
  *) usage ;;
esac
[ -f "$LIST" ] || { echo "list not found: $LIST" >&2; exit 1; }

DNT_FILE=$(dirname "$0")/lists/do-not-touch.txt
[ -f "$DNT_FILE" ] || { echo "do-not-touch list not found: $DNT_FILE" >&2; exit 1; }
DO_NOT_TOUCH=$(sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$DNT_FILE")

reachable() { "$ADB" -s "$SERIAL" get-state >/dev/null 2>&1; }
lost() { echo "device $SERIAL not reachable; stopped at $1" >&2; exit 1; }

reachable || { echo "device $SERIAL not reachable" >&2; exit 1; }
[ "$APPLY" -eq 1 ] || echo "DRY RUN (add --apply to change the device)"

failed=0; refused=0
while IFS= read -r p || [ -n "$p" ]; do
  p=$(printf '%s' "$p" | sed 's/#.*//; s/[[:space:]]//g')
  [ -n "$p" ] || continue
  for d in $DO_NOT_TOUCH; do
    [ "$p" = "$d" ] && { echo "REFUSED (do-not-touch): $p"; refused=$((refused + 1)); continue 2; }
  done
  # An adb error also prints no "package:" line, so rule out a lost device
  # before calling the package missing.
  if ! "$ADB" -s "$SERIAL" shell -n pm path "$p" 2>/dev/null | tr -d '\r' | grep -q '^package:'; then
    reachable || lost "$p"
    echo "skip (not installed for user 0): $p"; continue
  fi
  if [ "$APPLY" -eq 0 ]; then
    echo "would run: adb -s $SERIAL shell $CMD $p"; continue
  fi
  # shellcheck disable=SC2086 # $CMD must split into words
  out=$("$ADB" -s "$SERIAL" shell -n $CMD "$p" 2>&1 | tr -d '\r')
  echo "$p: $out"
  case "$out" in
    *Success*|*"new state: disabled"*)
      mkdir -p "$RECORD_DIR"
      grep -qx "$p" "$RECORD" 2>/dev/null || echo "$p" >> "$RECORD" ;;
    *)
      reachable || lost "$p"
      failed=$((failed + 1)) ;;
  esac
done < "$LIST"

[ "$refused" -eq 0 ] || echo "$refused package(s) refused (do-not-touch)."
[ "$APPLY" -eq 0 ] || echo "Recorded in $RECORD. Reboot, re-measure, and re-check package state."
if [ "$failed" -gt 0 ]; then
  echo "$failed package(s) failed; review the output above." >&2
  exit 1
fi
exit 0
