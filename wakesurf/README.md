# Wakesurf Tracker (Garmin Connect IQ)

A watch app for tracking boat **wakesurfing** — built for the Garmin Forerunner 255
(and other Connect IQ watches). It records a real activity session and tracks:

- **Active time** and **heart rate**
- **Run count** — automatically detected from GPS speed, with a manual button override
- **Average speed**, plus **max speed**, **distance**, **calories**, and **longest run**
- Metric units throughout (**km** / **km/h**)

Runs, max speed, and longest run are written into the FIT file as custom
`FitContributor` fields; time, HR, average speed, distance, and calories are native FIT data.
The activity is recorded as **Surfing** (the closest sport to wakesurfing), so it reads as
"Surfing" in Garmin Connect and syncs to Strava as a **Surf** activity.

---

## What it looks like

Three glanceable, button-driven **4-field** pages (no touchscreen on the FR255). A colored
top **arc** shows ride state at a glance from the boat: **green = RIDING**, **amber = WAITING**,
**blue = PAUSED**.

| Page | Shows (4 quadrants) |
|------|------|
| **Main** (default) | time · speed · heart rate · runs |
| **Totals** | avg speed · max speed · distance · calories |
| **Runs** | run count · this-run time · longest run · run top speed |

### Controls (FR255) — modeled on native running

| Button | Action |
|--------|--------|
| **START/STOP** | Not recording → **start**. Recording → **pause + stop menu** (Resume / Save / Discard). Resume is highlighted, so START again = resume |
| **BACK** | **Lap** — mark or correct a run while active (ignored on the splash so it can't exit mid-session) |
| **UP / DOWN** | Cycle data pages |
| **LIGHT** | Backlight — normal watch behavior (the app never captures it) |

On the **Press START** splash, a colored dot + word shows GPS readiness (No GPS → Acquiring → Weak → Good → **Ready**), updating live as the fix improves.

---

## Prerequisites (one-time)

1. **Connect IQ SDK** — install the [SDK Manager](https://developer.garmin.com/connect-iq/sdk/),
   then use its **Devices** tab to download **Forerunner 255**.
2. **VS Code** + the official **Monkey C** extension (publisher: Garmin).
3. **Developer key** — in VS Code: `Ctrl+Shift+P` → **Monkey C: Generate a Developer Key**.
4. Verify with `Ctrl+Shift+P` → **Monkey C: Verify Installation**.

---

## Build & run in the simulator

1. Open this folder in VS Code.
2. `Ctrl+Shift+P` → **Monkey C: Build Current Project** (choose `forerunner255`), then **Run**.
   The Connect IQ **simulator** launches with the app.
3. To exercise speed/HR and auto run detection without leaving your desk, in the simulator:
   **Simulation → FIT Data → Playback File…** and pick a FIT with boat-like speeds. Watch the
   band flip **RIDING/WAITING** at the thresholds and the run count tick up.

CLI alternative, from the repo root (see the [root README](../README.md)):
```
./build.sh wakesurf run
```

---

## Put it on your watch (sideload)

1. Build a release `.prg` (VS Code: **Monkey C: Build for Device** / **Export Project**, or
   `./build.sh wakesurf`).
2. Connect the FR255 by USB (it mounts as a drive).
3. Copy `bin/wakesurf.prg` into the watch's **`GARMIN/Apps/`** folder.
4. Eject, then launch **Wakesurf** from the watch's activity/app list.

> **Note on Garmin Connect:** Custom Connect IQ fields (run count, max speed, longest run) only
> render in Garmin Connect for apps that are **store-approved or installed as a private beta**.
> A pure USB sideload still records everything into the FIT file, but Connect won't draw the custom
> fields until you publish the app as a beta (easy) or to the store.

---

## Tuning run detection

The auto-detection thresholds live as named constants at the top of
[`source/RunTracker.mc`](source/RunTracker.mc):

```
START_SPEED   = 4.0   // ~14 km/h : speed to start a run
STOP_SPEED    = 2.7   // ~10 km/h : speed below which a run may be ending
MIN_RUN_SEC   = 5     // ignore runs shorter than this
END_GRACE_SEC = 4     // low-speed seconds tolerated before ending a run
```

After your first real session, adjust these to match your boat and riding. If auto-detection
ever misses or over-counts, the **START button acts as a manual run marker** in the moment.

---

## Project layout

```
manifest.xml              app id, entry, min API, permissions, target devices
monkey.jungle             build config
resources/
  strings/strings.xml     app name
  drawables/              launcher icon
source/
  WakesurfApp.mc          app entry point
  WakesurfView.mc         3-page UI, 1 Hz tick, rendering
  WakesurfDelegate.mc     button handling
  RunTracker.mc           session + FIT fields + run-detection state machine
  SessionMenuDelegate.mc  save / discard / resume menu
```
