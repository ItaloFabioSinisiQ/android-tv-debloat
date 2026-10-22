#!/bin/sh
# Find an Android TV with wireless debugging on (via mDNS) and connect to it.
# Pairing (adb pair) must have been done once before; see docs/guide.md.
set -eu

usage() {
  cat >&2 <<'EOF'
usage: connect.sh [TV_IP:PORT]

Without an argument, lists the _adb-tls-connect services found by
`adb mdns services` and connects to the first one.
With an argument, connects to that address directly.

Set ADB=/path/to/adb if adb is not on your PATH.
EOF
  exit 2
}

ADB=${ADB:-adb}
command -v "$ADB" >/dev/null 2>&1 || { echo "adb not found (set ADB=/path/to/adb)" >&2; exit 1; }

case "${1:-}" in -h|--help) usage ;; esac
[ $# -le 1 ] || usage

if [ $# -eq 1 ]; then
  target=$1
else
  services=$("$ADB" mdns services 2>/dev/null | tr -d '\r' | awk '/_adb-tls-connect/ {print $NF}')
  if [ -z "$services" ]; then
    echo "No _adb-tls-connect service found." >&2
    echo "Check that Wireless debugging is ON, the TV and computer are on the same network," >&2
    echo "and that this computer was paired (adb pair <TV_IP>:<PAIRING_PORT> <CODE>)." >&2
    exit 1
  fi
  count=$(printf '%s\n' "$services" | wc -l | tr -d ' ')
  if [ "$count" -gt 1 ]; then
    echo "Several devices found; using the first. Pass one explicitly to choose:" >&2
    printf '%s\n' "$services" | sed 's/^/  /' >&2
  fi
  target=$(printf '%s\n' "$services" | head -n 1)
fi

out=$("$ADB" connect "$target" 2>&1 | tr -d '\r')
echo "$out"
# adb connect exits 0 even on failure, so check the message.
case "$out" in
  *"connected to"*) ;;
  *) exit 1 ;;
esac

"$ADB" devices -l
echo
echo "Use this serial with the other scripts: $target"
