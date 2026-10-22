#!/bin/sh
# Show a test pattern on a TCL Google TV with the built-in image viewer.
# Changes nothing persistent besides the pushed file; remove it when done.
set -eu

usage() {
  cat >&2 <<'EOF'
usage: show-pattern.sh SERIAL FILE.jpg
       show-pattern.sh SERIAL --clean

  SERIAL    adb serial, e.g. <TV_IP>:<PORT>
  FILE.jpg  a 1920x1080 JPEG from scripts/patterns.py (*-1080.jpg)
  --clean   delete the pushed folder and its media index entries

The TCL viewer only opened file:// URIs to 1920x1080 JPEGs on the reference
TV; PNG, 4K and content:// URIs failed with "cannot play image".
Other brands need a different viewer component (set VIEWER=pkg/.Activity).
EOF
  exit 2
}

case "${1:-}" in ''|-h|--help) usage ;; esac
[ $# -eq 2 ] || usage
SERIAL=$1; FILE=$2
ADB=${ADB:-adb}
DIR=/sdcard/Pictures/tv-patterns
VIEWER=${VIEWER:-com.tcl.ui_mediaCenter/com.tcl.picture_business.PictureActivity}

"$ADB" -s "$SERIAL" get-state >/dev/null || { echo "device $SERIAL not reachable" >&2; exit 1; }

if [ "$FILE" = --clean ]; then
  "$ADB" -s "$SERIAL" shell am force-stop "${VIEWER%%/*}"
  "$ADB" -s "$SERIAL" shell rm -rf "$DIR"
  "$ADB" -s "$SERIAL" shell content delete --uri content://media/external/images/media \
    --where "\"_data LIKE '%/Pictures/tv-patterns/%'\""
  echo "Removed $DIR from the TV."
  exit 0
fi

[ -f "$FILE" ] || { echo "file not found: $FILE" >&2; exit 1; }
case "$FILE" in *.jpg|*.jpeg) ;; *) echo "warning: the TCL viewer only opened JPEGs" >&2 ;; esac
name=$(basename "$FILE")

"$ADB" -s "$SERIAL" shell mkdir -p "$DIR"
"$ADB" -s "$SERIAL" push "$FILE" "$DIR/$name" >/dev/null
# A running viewer ignores a new intent and keeps the old image.
"$ADB" -s "$SERIAL" shell am force-stop "${VIEWER%%/*}"
"$ADB" -s "$SERIAL" shell am start -a android.intent.action.VIEW \
  -d "file://$DIR/$name" -t image/jpeg -n "$VIEWER" >/dev/null

echo "Showing $name. Look at the TV: screencap cannot capture this viewer's layer."
echo "Note: VIEWER defaults to the TCL media center; other brands need their own."
echo "When finished: scripts/show-pattern.sh $SERIAL --clean"
