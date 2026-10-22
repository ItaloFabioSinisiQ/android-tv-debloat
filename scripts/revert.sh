#!/bin/sh
# Undo the debloat: restore packages removed for user 0, then re-enable the
# disabled ones. Reads uninstalled_by_us.txt and disabled_by_us.txt.
set -u

usage() {
  echo "usage: revert.sh SERIAL [LIST_DIR]" >&2
  echo "  SERIAL    adb serial, e.g. <TV_IP>:<PORT> (the port changes after each reboot)" >&2
  echo "  LIST_DIR  folder with uninstalled_by_us.txt / disabled_by_us.txt (default: .)" >&2
  exit 2
}

case "${1:-}" in ''|-h|--help) usage ;; esac
SERIAL=$1
DIR=${2:-.}
ADB=${ADB:-adb}
fail=0

"$ADB" -s "$SERIAL" get-state >/dev/null || { echo "device $SERIAL not reachable" >&2; exit 1; }

# `shell -n` is required: without it adb reads the loop's stdin and only the
# first package gets processed.
run_list() {
  file=$1; shift
  [ -f "$file" ] || { echo "skip: $file not found"; return 0; }
  while IFS= read -r p || [ -n "$p" ]; do
    case "$p" in ''|'#'*) continue ;; esac
    out=$("$ADB" -s "$SERIAL" shell -n "$@" "$p" 2>&1 | tr -d '\r')
    echo "$p: $out"
    case "$out" in *rror*|*xception*|*"not installed"*|*"Unknown package"*) fail=$((fail + 1)) ;; esac
  done < "$file"
}

echo "== restoring packages removed for user 0"
run_list "$DIR/uninstalled_by_us.txt" cmd package install-existing --user 0
echo "== re-enabling disabled packages"
run_list "$DIR/disabled_by_us.txt" pm enable --user 0

echo
[ "$fail" -eq 0 ] && echo "Done. Reboot the TV to return to a clean state." \
                  || echo "Done with $fail failure(s); review the output above."
[ "$fail" -eq 0 ]
