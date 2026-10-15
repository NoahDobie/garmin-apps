# Garmin Connect IQ Apps

Personal watch apps for the Garmin **Forerunner 255** (and other Connect IQ watches).

| App | What it does |
|-----|--------------|
| [`wakesurf/`](wakesurf/) | Boat wakesurfing: time, HR, auto-detected runs, speed, distance, calories |
| [`walking-pad/`](walking-pad/) | Under-desk walking pad: time, HR, calories, plus steps and distance estimated from your speed and cadence |

Each folder is a standalone Connect IQ project (`manifest.xml`, `monkey.jungle`, `source/`,
`resources/`) with its own README.

## Setup (one-time)

1. **Connect IQ SDK.** Install the [SDK Manager](https://developer.garmin.com/connect-iq/sdk/),
   then download an SDK and the **Forerunner 255** device.
2. **Developer key.** In VS Code with the Monkey C extension, run **Monkey C: Generate a Developer Key**.
   Save it to `~/.garmin/developer_key`, or set `GARMIN_KEY` to its path.
   It is git-ignored; never commit it.
3. **Java 17+** on PATH, or a JRE unpacked to `~/.garmin/jre`.

## Build & run

From Git Bash:

```
./build.sh walking-pad          # -> walking-pad/bin/walking-pad.prg
./build.sh wakesurf run         # build, open the simulator, load the app
./build.sh walking-pad fr965    # another device (must be listed in that app's manifest)
```

You can also open an app folder in VS Code and use **Monkey C: Build Current Project**.

**Sideload:** connect the watch by USB, then copy the `.prg` into `GARMIN/Apps/`.

## Adding an app

1. Create a new folder with its own `manifest.xml` (with a fresh app id), `monkey.jungle`, `source/` and `resources/`.
2. Run `./build.sh <folder>`.
3. Add it to the table above.
