# Package reference: TCL G08 board (Android 14)

Observed on a TCL 65C6K (Google TV, Android 14, product `G08_4K_GB`) on 2026-10-20 and 2026-10-21. Other TCL boards and firmware versions may name, bundle or depend on these packages differently. Check that a package exists on your TV (`adb shell pm path <pkg>`) and read its row before touching it.

## How to read this table

| Column | Meaning |
|--------|---------|
| Action | **disabled**: `pm disable-user --user 0`, stayed disabled across reboots. **uninstalled-for-user**: `pm uninstall -k --user 0`, because the firmware re-enabled it at boot. **kept**: evaluated and left alone. **NEVER touch**: breaks core TV functions. |
| Risk | **Low**: no loss for most users. **Medium**: removes a feature some people use, or holds hardware-related permissions. **High**: reported to break something essential. |
| RAM | Approximate resident memory where it was measured (`dumpsys -t 60 meminfo`). |

Copy of `docs/packages-tcl-g08.md` from the android-tv-debloat repository, bundled so the skill works standalone. The repository also ships batch files under `scripts/lists/`.

## Batch 1: disabled (persisted with `pm disable-user`)

| Package | What it is | What you lose | Risk | Action |
|---------|------------|---------------|------|--------|
| `com.tcl.channelplus` | TCL Channel, ad-supported free channels | TCL Channel | Low | disabled |
| `com.tcl.waterfall.overseas` | TCL Channel icon and channel rows | TCL Channel rows | Low | disabled |
| `com.tcl.partnercustomizer` | TCL Channel partner customization | Nothing visible | Low | disabled |
| `com.tcl.esticker` | On-screen promotional stickers | Promotions | Low | disabled |
| `com.tcl.messagebox` | Promotional messages | Promotions | Low | disabled |
| `com.tcl.exhibit` | Store demo mode | Demo mode | Low | disabled |
| `com.tcl.hotelmenu` | Hotel mode | Hotel mode | Low | disabled |
| `com.tcl.repairguide` | Repair guide | Built-in repair guide | Low | disabled |
| `com.tcl.ocean.instructions` | On-device manual | Built-in manual | Low | disabled |
| `com.tcl.smartalexa` | TCL Alexa integration | Alexa control | Low | disabled |
| `com.tcl.t_solo` | T-Solo, TV audio on a phone | Private listening via phone | Low | disabled |
| `com.tcl.airplay2` | AirPlay receiver (TCL) | AirPlay from Apple devices | Medium | disabled |
| `com.mediatek.AirplayAPK` | AirPlay receiver (MediaTek) | AirPlay | Medium | disabled |
| `com.mediatek.airplaydaemon` | AirPlay daemon | AirPlay | Medium | disabled |
| `com.google.android.play.games` | Google Play Games | Play Games app | Low | disabled |
| `com.google.android.feedback` | Google feedback reporter | Sending feedback to Google | Low | disabled |

## Batch 2: uninstalled for user 0 (firmware re-enabled them after `disable-user`)

| Package | What it is | What you lose | Risk | Action |
|---------|------------|---------------|------|--------|
| `com.google.android.syncadapters.calendar` | Google Calendar sync (~111 MB) | Calendar sync on the TV | Low | uninstalled-for-user |
| `com.tcl.ttvs` | TCSCore: Samba TV content recognition (ACR), analytics, Alexa, T-Cast (~78 MB) | T-Cast. **Not** the system update service | Medium | uninstalled-for-user |
| `com.tcl.miracast` | Miracast screen mirroring from Android phones (~45 MB) | Miracast mirroring. Chromecast built-in still works | Medium | uninstalled-for-user |
| `com.tcl.logkit` | TCL logging | Nothing visible | Low | uninstalled-for-user |
| `com.tcl.usercenter` | TCL account | TCL account features | Low | uninstalled-for-user |
| `com.tcl.tv.tclhome_passive` | TCL home passive service | Nothing visible | Low | uninstalled-for-user |
| `com.tcl.interactive` | TCL interactive content / silent installer | Nothing visible | Low | uninstalled-for-user |
| `com.tcl.guard` | TCL "cleaner" | Its cleaner | Low | uninstalled-for-user |
| `com.tcl.UpdatePeripheral` | Firmware updater for TCL peripherals (e.g. soundbars) | Peripheral firmware updates | Medium | uninstalled-for-user |
| `com.tcl.smartlink.core` | TCL smart link | Nothing visible | Low | uninstalled-for-user |
| `android.autoinstalls.config.google.gtvpai` | Google TV partner auto-install config | Automatic partner app installs | Low | uninstalled-for-user |
| `com.google.android.partnersetup` | Partner setup | Nothing visible | Low | uninstalled-for-user |
| `com.android.tv.feedbackconsent` | Feedback consent | Nothing visible | Low | uninstalled-for-user |

> [!WARNING]
> Six packages in this batch hold `TV_INPUT_HARDWARE` or `HDMI_CEC` permissions and run with the system UID. HDMI inputs on this board are served by `com.tcl.tvinput`, so removing them did not affect HDMI here, but **test every HDMI input after this batch**.

> [!NOTE]
> `com.tcl.ttvs` was first believed to handle system updates. It does not: on this TV the system update screen resolves to `com.google.android.gms/.update.SystemUpdatePanoActivity`. Check yours with `adb shell cmd package resolve-activity --brief -a android.settings.SYSTEM_UPDATE_SETTINGS`.

## Preinstalled third-party apps removed

| Package | What it is | Action | Revert |
|---------|------------|--------|--------|
| `com.iqiyi.i18n.tv` | iQIYI streaming app | `pm uninstall --user 0` | Reinstall from Play Store |
| `com.mercadolibre.android.mplay_tv` | Mercado Play streaming app | `pm uninstall --user 0` | Reinstall from Play Store |

## Kept on purpose

| Package | What it is | Why it was kept |
|---------|------------|-----------------|
| `com.google.android.apps.tv.launcherx` | Google TV home screen | Stock launcher preferred; a third-party launcher showed no real-world gain |
| `com.google.android.gms` | Google Play services | Required by almost everything, including system updates |
| `com.google.android.katniss` | Google voice search / Assistant | Voice search wanted. Its `:interactor` process uses about 15 to 25% of one core on the built-in mic even with the Assistant off; no safe way to stop that was found |
| `com.tcl.dashboard`, `com.tcl.systemserver`, `com.tcl.systemui.plugin`, `com.tvos` | TCL system UI and services | Core system components |
| `com.mediatek.*` (other than AirPlay) | MediaTek platform services | Core system components |
| Keyboards and input methods | On-screen keyboard | Needed for text input |

## Do not touch

Breaking any of these was observed on the reference TV or reported for this board by other users. Losing Wi-Fi also cuts wireless ADB, so you may be unable to revert without Ethernet or a factory reset.

| Package | Consequence if disabled or removed |
|---------|------------------------------------|
| `com.tcl.tvinput` | HDMI inputs show "No Signal". It serves the HDMI TV inputs |
| `com.tcl.tv` | HDMI inputs show "No Signal" |
| `com.tcl.suspension` | HDMI "No Signal"; the Quick Panel (settings button menu) stops working |
| `com.tcl.providers.config` | Wi-Fi drops |
| `com.tcl.initsetup` | Wi-Fi drops; initial setup breaks |
| `com.tcl.factory.view` | Wi-Fi drops |
| `com.google.android.tv.remote.service` | The remote's voice button (mic) stops working |
| `com.google.android.katniss` | Voice search stops working |
| `com.tcl.gamebar` | Game bar and HDMI game-mode handling for consoles. It was disabled by mistake once and re-enabled |
| `com.google.android.apps.tv.launcherx` | No home screen unless another launcher is installed |
| `com.google.android.tungsten.setupwraith` | Google TV setup wizard. Not tested; removing setup components risks a TV that cannot complete setup after a reset |

`scripts/debloat.sh` refuses every package in this list.

## Related settings tried and reverted

| Setting | Result |
|---------|--------|
| `settings put global tcl_app_settings_micro_phone false` | No effect, even after reboot. Restored to `true` |
| `appops set com.google.android.katniss RECORD_AUDIO_HOTWORD ignore` | Mic hotword silenced (`silenced:true`) but `katniss:interactor` CPU unchanged, even after force-stop. Restored to `allow` |
| Android global microphone privacy toggle | Not tried: it blocks the mic for everything and likely disables remote voice search too, which uses the separate `RECORD_AUDIO` op |
