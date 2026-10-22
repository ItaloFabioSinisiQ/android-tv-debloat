#!/bin/sh
# Offline tests for scripts/. A fake `adb` on PATH stands in for the TV;
# no real device is contacted. Usage: sh tests/run.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tv-debloat-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/bin"
PATH="$WORK/bin:$PATH"
unset ADB
export PATH

# Fake adb. Behaviour is driven by files in $FAKE_DIR:
#   offline       get-state and shell fail (device unreachable)
#   shell_fail    get-state works, every shell command fails
#   drop_on_path  the first `pm path` disconnects the device
#   missing       space-separated packages that are not installed
#   failing       space-separated packages whose state change fails
# Every call is appended to $FAKE_DIR/log.
cat > "$WORK/bin/adb" <<'EOF'
#!/bin/sh
echo "$*" >> "$FAKE_DIR/log"
[ "${1:-}" = -s ] && shift 2
listed() { case " $(cat "$FAKE_DIR/$1" 2>/dev/null) " in *" $2 "*) return 0 ;; esac; return 1; }
case "${1:-}" in
  get-state)
    [ -f "$FAKE_DIR/offline" ] && { echo "error: device offline" >&2; exit 1; }
    echo device; exit 0 ;;
  shell) shift; [ "${1:-}" = -n ] && shift ;;
  *) echo "fake adb: unsupported: $*" >&2; exit 1 ;;
esac
if [ -f "$FAKE_DIR/offline" ] || [ -f "$FAKE_DIR/shell_fail" ]; then
  echo "error: closed" >&2; exit 1
fi
cmd=$*
p=${cmd##* }
case "$cmd" in
  "pm path "*)
    if [ -f "$FAKE_DIR/drop_on_path" ]; then
      : > "$FAKE_DIR/offline"; echo "error: closed" >&2; exit 1
    fi
    listed missing "$p" && exit 1
    printf 'package:/system/app/%s.apk\r\n' "$p" ;;
  "pm disable-user --user 0 "*)
    listed failing "$p" && { printf 'Error: java.lang.SecurityException: %s\r\n' "$p"; exit 255; }
    printf 'Package %s new state: disabled-user\r\n' "$p" ;;
  "pm uninstall -k --user 0 "*)
    listed failing "$p" && { printf 'Failure [DELETE_FAILED_INTERNAL_ERROR]\r\n'; exit 1; }
    printf 'Success\r\n' ;;
  "pm enable --user 0 "*) printf 'Package %s new state: enabled\r\n' "$p" ;;
  "cmd package install-existing --user 0 "*) printf 'Package %s installed for user: 0\r\n' "$p" ;;
  "pm list packages"*) printf 'package:com.example.two\r\npackage:com.example.one\r\n' ;;
  "settings list "*) printf 'b=2\r\na=1\r\n' ;;
  "settings get "*) printf '1\r\n' ;;
  getprop) printf '[ro.product.model]: [TV]\r\n' ;;
  "getprop "*) printf 'value\r\n' ;;
  "cat /proc/meminfo") printf 'MemTotal: 2400000 kB\r\n' ;;
  uptime) printf ' 10:00:00 up 1 day\r\n' ;;
  *) echo "fake adb: unsupported shell command: $cmd" >&2; exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/adb"

pass=0; fail=0
check() {
  desc=$1; shift
  if "$@"; then pass=$((pass + 1)); echo "ok   - $desc"
  else fail=$((fail + 1)); echo "FAIL - $desc"; fi
}
reset() {
  FAKE_DIR=$WORK/fake.$1; mkdir -p "$FAKE_DIR"; : > "$FAKE_DIR/log"; export FAKE_DIR
  REC=$WORK/rec.$1
}
not()        { ! "$@"; }
logged()     { grep -q -- "$1" "$FAKE_DIR/log"; }
not_logged() { ! grep -q -- "$1" "$FAKE_DIR/log"; }
has()        { printf '%s\n' "$OUT" | grep -q -- "$1"; }
lacks()      { ! printf '%s\n' "$OUT" | grep -q -- "$1"; }
is()         { [ "$RC" -eq "$1" ]; }
nonzero()    { [ "$RC" -ne 0 ]; }
run()        { OUT=$("$@" 2>&1); RC=$?; }
debloat()    { run sh "$ROOT/scripts/debloat.sh" S "$@"; }

LIST=$WORK/list.txt
DNT=$ROOT/scripts/lists/do-not-touch.txt
dnt_list() { sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$DNT" | sort; }
dnt_doc() {
  awk '/^## Do not touch/ { f = 1; next } /^## / { f = 0 }
       f && /^\| `/ { split($0, a, "`"); print a[2] }' "$1" | sort
}

echo "# debloat.sh"

reset refuse
{ echo com.tcl.tvinput; [ -f "$DNT" ] && dnt_list; } | sort -u > "$LIST"
debloat "$LIST" --record-dir "$REC" --apply
check "refuses a do-not-touch package" has "REFUSED (do-not-touch): com.tcl.tvinput"
check "refuses every entry of lists/do-not-touch.txt" \
  [ "$(printf '%s\n' "$OUT" | grep -c '^REFUSED')" -eq "$(wc -l < "$LIST")" ]
check "sends no change command for refused packages" not_logged "disable-user"
check "records nothing for refused packages" [ ! -s "$REC/disabled_by_us.txt" ]

reset dry
echo com.tcl.channelplus > "$LIST"
debloat "$LIST" --record-dir "$REC"
check "dry run exits 0" is 0
check "dry run prints the command it would run" has "would run: .*disable-user --user 0 com.tcl.channelplus"
check "dry run sends no change command" not_logged "disable-user"
check "dry run writes no revert list" [ ! -e "$REC/disabled_by_us.txt" ]

reset apply
printf 'com.tcl.channelplus\n# comment\n\ncom.tcl.esticker\n' > "$LIST"
debloat "$LIST" --record-dir "$REC" --apply
debloat "$LIST" --record-dir "$REC" --apply
check "--apply exits 0 when every package succeeds" is 0
check "--apply runs disable-user" logged "shell -n pm disable-user --user 0 com.tcl.channelplus"
check "--apply records to disabled_by_us.txt without duplicates" \
  [ "$(cat "$REC/disabled_by_us.txt" 2>/dev/null)" = "$(printf 'com.tcl.channelplus\ncom.tcl.esticker')" ]
debloat "$LIST" --method uninstall --record-dir "$REC" --apply
check "--method uninstall records to uninstalled_by_us.txt" grep -qx com.tcl.esticker "$REC/uninstalled_by_us.txt"

reset failpkg
printf 'com.tcl.channelplus\ncom.tcl.esticker\n' > "$LIST"
echo com.tcl.channelplus > "$FAKE_DIR/failing"
debloat "$LIST" --record-dir "$REC" --apply
check "exits non-zero when a package fails" nonzero
check "keeps going after a failed package" logged "disable-user --user 0 com.tcl.esticker"
check "does not record the failed package" not grep -qx com.tcl.channelplus "$REC/disabled_by_us.txt"

reset missing
echo com.tcl.channelplus > "$LIST"
echo com.tcl.channelplus > "$FAKE_DIR/missing"
debloat "$LIST" --record-dir "$REC" --apply
check "skips a package that is not installed" has "skip (not installed for user 0): com.tcl.channelplus"
check "a missing package is not a failure" is 0

reset drop
printf 'com.tcl.channelplus\ncom.tcl.esticker\n' > "$LIST"
: > "$FAKE_DIR/drop_on_path"
debloat "$LIST" --record-dir "$REC" --apply
check "exits non-zero when the device disconnects" nonzero
check "does not report a disconnect as 'not installed'" lacks "not installed"
check "says the device is not reachable" has "not reachable"

reset offline
echo com.tcl.channelplus > "$LIST"
: > "$FAKE_DIR/offline"
debloat "$LIST" --record-dir "$REC" --apply
check "exits non-zero when the device is unreachable" nonzero

echo "# revert.sh"

reset revert_none
mkdir -p "$REC"
run sh "$ROOT/scripts/revert.sh" S "$REC"
check "fails when neither revert list exists" nonzero
check "explains that no revert list was found" has "no revert list"

reset revert_ok
mkdir -p "$REC"
echo com.tcl.channelplus > "$REC/disabled_by_us.txt"
echo com.tcl.ttvs > "$REC/uninstalled_by_us.txt"
run sh "$ROOT/scripts/revert.sh" S "$REC"
check "reverts both lists and exits 0" is 0
check "re-enables disabled packages" logged "pm enable --user 0 com.tcl.channelplus"
check "restores removed packages" logged "install-existing --user 0 com.tcl.ttvs"

echo "# backup.sh"

reset backup_ok
run sh "$ROOT/scripts/backup.sh" S "$REC"
check "backup exits 0 on a reachable device" is 0
check "backup writes sorted package lists" \
  [ "$(cat "$REC/packages_all.txt" 2>/dev/null)" = "$(printf 'com.example.one\ncom.example.two')" ]

reset backup_offline
: > "$FAKE_DIR/offline"
run sh "$ROOT/scripts/backup.sh" S "$REC"
check "backup fails fast when the device is unreachable" nonzero

reset backup_shellfail
: > "$FAKE_DIR/shell_fail"
run sh "$ROOT/scripts/backup.sh" S "$REC"
check "backup fails when an adb shell command fails" nonzero

echo "# docs"

check "scripts/lists/do-not-touch.txt exists" [ -f "$DNT" ]
if [ -f "$DNT" ]; then
  dnt_list > "$WORK/dnt.list"
  for doc in docs/packages-tcl-g08.md skills/android-tv-debloat/references/packages-tcl-g08.md; do
    dnt_doc "$ROOT/$doc" > "$WORK/dnt.doc"
    check "do-not-touch table in $doc matches the list file" cmp -s "$WORK/dnt.list" "$WORK/dnt.doc"
  done
fi
grep -v 'copy-specific' "$ROOT/docs/packages-tcl-g08.md" > "$WORK/pkg.docs"
grep -v 'copy-specific' "$ROOT/skills/android-tv-debloat/references/packages-tcl-g08.md" > "$WORK/pkg.skill"
check "skill package reference is in sync with docs/packages-tcl-g08.md" cmp -s "$WORK/pkg.docs" "$WORK/pkg.skill"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
