# Picture tuning without a colorimeter

Agent reference. The human-facing version with full explanations is `docs/picture-calibration.md` in the android-tv-debloat repository. Observed on a TCL 65C6K (Google TV, Android 14).

## Scope

| Possible without a meter | Needs a colorimeter + HCFR (free) or Calman |
|--------------------------|---------------------------------------------|
| Most accurate preset, processing off | Grayscale / white balance |
| Black level and white clipping by eye | Color gamut, color management |
| Console HDR calibration (PS5: Settings › Screen and Video › Video Output › Adjust HDR) | |

Never use a phone camera (auto white balance and exposure). `screencap` shows the composed UI, not panel light, and is empty while DRM apps (Netflix) play; `uiautomator dump` still reads menu text drawn on top.

## Workflow

1. Read current values (RO) and record them.
2. Propose the preset: FILMMAKER MODE, else Movie/Cinema + Warm + sharpness 0 (ASK).
3. Repeat per signal format (SDR, HDR, Dolby Vision) and per HDMI input: values are stored separately. Keep Dolby Vision IQ if offered (adapts to room light).
4. Patterns: `python3 scripts/patterns.py OUT_DIR`, show `black-level-1080.jpg` and `white-clip-1080.jpg`. Ask only the questions in the table below, batched.
5. Revert: Picture › Picture mode › previous mode.

## Commands (TCL)

| Kind | Command |
|------|---------|
| ASK (changes screen) | `am start -a android.settings.DISPLAY_SETTINGS -n com.android.tv.settings/com.tcl.settings.PictureActivity` (works over any app) |
| RO | `uiautomator dump /sdcard/ui.xml && cat /sdcard/ui.xml`; read `text` and `focused="true"` |
| ASK | `input keyevent KEYCODE_DPAD_UP|DOWN|LEFT|RIGHT|CENTER|BACK` |
| ASK | `scripts/show-pattern.sh SERIAL FILE-1080.jpg`; `scripts/show-pattern.sh SERIAL --clean` when done |

Navigation rules: the picture-mode list is horizontal and moving focus may apply a mode instantly. Dump and read the focused node before every CENTER.

Image viewer `com.tcl.ui_mediaCenter/com.tcl.picture_business.PictureActivity`: only `file://` URIs to 1920×1080 JPEG (quality 100, no chroma subsampling) opened; PNG, 4K and `content://` failed with "cannot play image". `am force-stop com.tcl.ui_mediaCenter` before each new image. `screencap` cannot see the viewer; the human reports what they see. Clean up the pushed folder and MediaStore rows. Other brands: different viewer (`VIEWER=pkg/.Activity`).

## Pattern questions

| Pattern | Ask | Pass | Fail → adjust |
|---------|-----|------|---------------|
| black-level | Is the background black? Which is the first bar you can see? | Black background, bar 2 to 4 first visible | Black level (Brightness) |
| white-clip | Up to which number can you tell bars apart? | About 253 to 255 | Contrast |
| grayscale | Any color tint or visible bands? | Neutral, smooth | Color temperature; residual tint needs a meter |
| sharpness | Outlines around lines or text? | None | Lower sharpness |

## Reference result (Smart → FILMMAKER MODE, SDR)

Backlight 22→34; contrast 100; black level 50; gamma 2.2→BT.1886; dynamic contrast Adaptive→Off; color temperature 0→5 (warm); color space Standard→Auto; sharpness 50→0; MPEG NR Medium→Off; noise reduction Auto→Off; smooth gradation Low→Off; motion clarity Medium→Off. Patterns: bar 1 merged, bar 2 visible (black level 50 OK); all white bars distinguishable (contrast 100 OK). Grayscale and sharpness not evaluated. No published C6K calibration exists; RTINGS settings for other TCL models were only a starting point.
