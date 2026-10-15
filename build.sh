#!/usr/bin/env bash
# Build (and optionally run) one of the apps in this repo.
#
#   ./build.sh <app> [device]        build <app>/bin/<app>.prg
#   ./build.sh <app> run [device]    build, then load it into the simulator
#
# device defaults to fr255. Local, never-committed inputs:
#   developer key  $GARMIN_KEY   (default ~/.garmin/developer_key)
#   Java           java on PATH, else ~/.garmin/jre
#   SDK            the one selected in the SDK Manager (current-sdk.cfg)
set -euo pipefail

usage() { echo "usage: $0 <app> [run] [device]   apps: $(ls -d */ | tr -d / | tr '\n' ' ')"; exit 1; }

cd "$(dirname "$0")"
app=${1:-}; [ -n "$app" ] && [ -f "$app/manifest.xml" ] || usage
shift
run=false
if [ "${1:-}" = run ]; then run=true; shift; fi
device=${1:-fr255}

home=$(cygpath -u "${USERPROFILE:-$HOME}" 2>/dev/null || echo "$HOME")
key=${GARMIN_KEY:-$home/.garmin/developer_key}
[ -f "$key" ] || { echo "No developer key at $key (generate one: VS Code > Monkey C: Generate a Developer Key)"; exit 1; }

if ! command -v java >/dev/null 2>&1; then
    export JAVA_HOME="$home/.garmin/jre"
    export PATH="$JAVA_HOME/bin:$PATH"
fi

cfg="${APPDATA:-$home/AppData/Roaming}/Garmin/ConnectIQ/current-sdk.cfg"
sdk=$(cygpath -u "$(tr -d '\r\n' < "$cfg")")
ext=""; [ -f "$sdk/bin/monkeyc.bat" ] && ext=".bat"

out="$app/bin/$app.prg"
"$sdk/bin/monkeyc$ext" -f "$app/monkey.jungle" -d "$device" -o "$out" -y "$key" -w
echo "-> $out"

if $run; then
    if ! tasklist 2>/dev/null | grep -qi simulator.exe; then
        "$sdk/bin/simulator.exe" >/dev/null 2>&1 &
        until tasklist | grep -qi simulator.exe; do sleep 1; done
        sleep 4
    fi
    "$sdk/bin/monkeydo$ext" "$out" "$device"
fi
