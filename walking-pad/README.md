# Walking Pad (Garmin Connect IQ)

A watch app for an **under-desk walking pad**, built for the Garmin Forerunner 255. The
built-in Treadmill activity guesses steps and distance from arm swing. With your hands on a
keyboard it sees almost nothing. This app records time, heart rate and **calories**
normally (they're HR-based), and **estimates steps and distance** from values you enter:

- **Distance** = treadmill speed (mph) × walking time, which you can correct at Save to match the treadmill display
- **Steps** = steps-per-minute (default 80) × walking minutes

The activity saves as **Walking → Indoor Walking**.

> **Daily step count:** Connect IQ apps *cannot* add to Garmin's daily step total. Daily
> steps come only from the watch's own accelerometer, and Garmin Connect has no way to add
> steps manually. The estimated steps are saved with the activity (as a custom field). To get
> walking-pad steps into your daily total, wear the watch on your **ankle or in a pocket** while
> walking. The **WATCH** field on page 2 shows what the watch itself counted, so you can compare.

---

## Using it

| Screen | Button | Action |
|--------|--------|--------|
| Splash | **START** | Speed picker (prefilled with last speed) → START again begins recording |
| Splash | **Hold UP** | Settings: steps/min, default speed |
| Splash | **BACK** | Exit |
| Recording | **START** | Pause + menu: **Resume** / **Change speed** / **Save** / **Discard** |
| Recording | **UP / DOWN** | Switch data page |
| Picker | **UP / DOWN** | ± one step (0.1 mph, 1 spm, 0.01 mi) |
| Save → distance picker | **START** / **BACK** | Save with the entered distance / save with the estimate |

**Pages:** TIME · HR · STEPS · MILES, and CAL · MPH · SPM · WATCH (steps the watch counted).
The top arc is green while walking and blue while paused.

---

## Build

From the repo root (see the [root README](../README.md) for one-time setup):

```
./build.sh walking-pad        # -> walking-pad/bin/walking-pad.prg
./build.sh walking-pad run    # build + load into the simulator
```

**Sideload:** plug in the FR255 by USB, copy `bin/walking-pad.prg` into `GARMIN/Apps/`, eject,
then launch **Walking Pad** from the activity list.

---

## FIT data

| Field | Message | Notes |
|-------|---------|-------|
| `distance` | record | meters, mapped to native distance (`nativeNum` 5) |
| `speed` | record | m/s, mapped to native speed (`nativeNum` 6) |
| `total_distance` | session | meters (the value from the Save picker), mapped to native total distance (`nativeNum` 9) |
| `steps`, `cadence`, `watch_steps` | session | custom |

As with the wakesurf app, Garmin Connect only renders Connect IQ developer fields for
**store or private-beta** installs. A USB sideload still writes them to the FIT file. If
distance doesn't show in Connect after a sideloaded walk, publish the app as a private beta.

## Layout

```
source/
  WalkingPadApp.mc          entry point
  WalkingPadView.mc         splash + 2 data pages, 1 Hz tick
  WalkingPadDelegate.mc     buttons, picker callbacks, stop menu
  PadTracker.mc             session, FIT fields, distance/step estimate, saved settings
  NumberPickerView.mc       reusable UP/DOWN number picker
  SessionMenuDelegate.mc    Resume / Change speed / Save / Discard
  SettingsMenuDelegate.mc   steps/min, default speed
```
