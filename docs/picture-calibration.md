# Picture tuning without a colorimeter

Without a measuring instrument you cannot calibrate a TV, but you can get close: pick the most accurate picture preset, then check black level and white clipping by eye with test patterns. On the reference TV (TCL 65C6K, Google TV, Android 14) that meant switching from **Smart** to **FILMMAKER MODE** and confirming that the default black level and contrast were already right.

> [!NOTE]
> Picture menus, names and storage differ between brands and firmware. The menu path and the image viewer below are TCL-specific; the method is not.

## Quick path

1. Pick the most accurate preset: **FILMMAKER MODE** if the TV has it, otherwise **Movie**/**Cinema**, color temperature **Warm**, sharpness **0**.
2. Repeat for each signal format you watch (SDR, HDR, Dolby Vision) and each HDMI input: settings are stored separately.
3. Generate test patterns: `python3 scripts/patterns.py patterns/`.
4. Show the black-level and white-clipping patterns on the TV and adjust only if they fail.
5. For a game console, run the console's own HDR calibration.

## What you can and cannot do without a meter

| Task | Without a meter | Needs a colorimeter |
|------|-----------------|---------------------|
| Choose the most accurate preset | Yes | |
| Black level (brightness control) | Yes, by eye with a pattern | |
| White clipping (contrast control) | Yes, by eye with a pattern | |
| Turn off processing (sharpening, noise reduction, motion smoothing) | Yes | |
| Grayscale / white balance (2- or 20-point) | | Yes, plus software such as HCFR (free) or Calman |
| Color gamut and color management | | Yes |
| HDR tone mapping for a console | Yes, with the console's HDR calibration | |

Do not use a phone camera as a meter. Phones apply automatic white balance and exposure, so the picture they record says more about the phone than the TV.

## 1. Choose the preset

FILMMAKER MODE disables the processing that moves the picture away from what the content was mastered for. On the reference TV it already applied every "expert" change usually recommended, so no manual adjustment was needed after selecting it.

Changes on the reference TV, SDR, Smart → FILMMAKER MODE:

| Setting | Smart | FILMMAKER MODE |
|---------|-------|----------------|
| Backlight ("Brillo" on a Spanish menu) | 22 | 34 |
| Contrast | 100 | 100 |
| Black level | 50 | 50 |
| Gamma | 2.2 | BT.1886 |
| Dynamic contrast | Adaptive | Off |
| Color temperature | 0 (normal) | 5 (warm) |
| Color space | Standard | Auto |
| Sharpness | 50 | 0 |
| MPEG noise reduction | Medium | Off |
| Noise reduction | Auto | Off |
| Smooth gradation | Low | Off |
| Motion clarity | Medium | Off |

Backlight is a comfort setting, not an accuracy one: set it for your room. With Dolby Vision content the menu showed **Dolby Vision IQ**, which adapts to room light; it was kept.

No published calibration for the C6K was found. [RTINGS settings for another TCL model](https://www.rtings.com/tv/reviews/tcl/6-series-r655-2022-qled/settings) (Movie mode, Warm, sharpness 0) were used only as a starting point.

Revert: **Settings › Picture › Picture mode** › the previous mode. Each mode keeps its own values.

## 2. Check black level and white clipping

Generate the patterns (needs Python 3 and Pillow, `pip install Pillow`):

```sh
python3 scripts/patterns.py patterns/
```

| Pattern | What to look for | Adjust | Reference TV result |
|---------|------------------|--------|---------------------|
| `black-level` | Background stays black; bar 2 to 4 is just visible | Black level (often called Brightness) | Bar 1 merged, bar 2 visible: black level 50 is correct |
| `white-clip` | Bars up to about 253 to 255 are distinguishable | Contrast | All bars distinguishable: contrast 100 is correct |
| `grayscale` | Ramp and 21 steps look neutral gray, without color tint or visible bands | Color temperature; a tint that remains needs a meter | Not evaluated |
| `sharpness` | No white or dark outlines around the lines and text | Sharpness (lower it) | Not evaluated |

Each pattern is written as a 3840×2160 PNG and as a 1920×1080 JPEG (`*-1080.jpg`). Show them from a USB stick, a casting app, or over ADB (next section). Look at the TV in your usual lighting, from your usual seat.

> [!TIP]
> Answering questions about faint bars is tiring. Check one pattern at a time, answer only what the table asks, and stop whenever you want: black level and white clipping are the two checks that matter most.

### Show a pattern over ADB (TCL)

```sh
scripts/show-pattern.sh <TV_IP>:<PORT> patterns/black-level-1080.jpg
scripts/show-pattern.sh <TV_IP>:<PORT> --clean       # when finished
```

What the script does, and what was learned on the reference TV:

| Fact | Detail |
|------|--------|
| Viewer | `com.tcl.ui_mediaCenter/com.tcl.picture_business.PictureActivity` |
| What opens | Only a `file://` URI to a 1920×1080 JPEG (quality 100, no chroma subsampling) |
| What fails | PNG, 4K images and `content://` URIs: "cannot play image" |
| Switching images | `am force-stop com.tcl.ui_mediaCenter` first; otherwise the intent goes to the running viewer and the old image stays |
| Feedback | The viewer draws on a layer `screencap` cannot capture; the person in front of the TV has to report what they see |
| Cleanup | Delete the pushed folder and its media index entries (`--clean`) |

Manual equivalent:

```sh
adb shell mkdir -p /sdcard/Pictures/tv-patterns
adb push patterns/black-level-1080.jpg /sdcard/Pictures/tv-patterns/
adb shell am force-stop com.tcl.ui_mediaCenter
adb shell am start -a android.intent.action.VIEW \
  -d file:///sdcard/Pictures/tv-patterns/black-level-1080.jpg -t image/jpeg \
  -n com.tcl.ui_mediaCenter/com.tcl.picture_business.PictureActivity
```

Other brands need a different viewer: find one with `adb shell cmd package query-activities -a android.intent.action.VIEW -t image/jpeg` and pass it as `VIEWER=<package>/<activity>`.

## 3. Console HDR calibration

Consoles map HDR to the panel's real peak brightness with their own calibration screens. Run it after choosing the picture mode for that HDMI input, with HDR content active.

- PS5: **Settings › Screen and Video › Video Output › Adjust HDR**.
- Xbox Series: the **HDR Game Calibration** app.

## Reading and changing picture settings over ADB

Useful when an agent assists, or to record before and after values. The commands below are TCL-specific except `uiautomator`.

| Action | Command |
|--------|---------|
| Open the TCL picture menu over any app | `adb shell am start -a android.settings.DISPLAY_SETTINGS -n com.android.tv.settings/com.tcl.settings.PictureActivity` |
| Read the values on screen | `adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml` (look at the `text` attributes) |
| Navigate | `adb shell input keyevent KEYCODE_DPAD_UP` (also `DOWN`, `LEFT`, `RIGHT`, `CENTER`, `BACK`) |

Precautions:

- The picture-mode list is horizontal, and moving focus over a mode may apply it immediately.
- Read the focused node (`focused="true"` in the dump) before every `KEYCODE_DPAD_CENTER`. In account menus a misplaced CENTER can select "Remove profile".
- `screencap` shows the composed UI, not the light the panel emits, so it cannot judge picture quality. While a DRM-protected app such as Netflix plays, the captured image is empty, but `uiautomator dump` still reads the text of a menu drawn on top.

## Checklist

- [ ] Most accurate preset selected for SDR, HDR and Dolby Vision, on each HDMI input you use.
- [ ] Black-level pattern: background black, bar 2 to 4 visible.
- [ ] White-clipping pattern: bars up to about 253 to 255 distinguishable.
- [ ] Console HDR calibration done, if you game.
- [ ] Test images removed from the TV.

## Next step

For accurate grayscale and color, borrow or rent a colorimeter and follow an HCFR or Calman workflow. Back to the [guide](guide.md).
