#!/usr/bin/env bash
set -u

SINK_NAME="${SHAZAM_SINK_NAME:-shazam_sink}"
SINK_DESCRIPTION="${SHAZAM_SINK_DESCRIPTION:-ShazamSink}"
LATENCY_MS="${SHAZAM_LOOPBACK_LATENCY_MS:-20}"

die() {
    printf '[CrateDigger] audio setup failed: %s\n' "$*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

need_cmd pactl
need_cmd awk
need_cmd grep

pactl info >/dev/null 2>&1 || die "cannot connect to the PulseAudio server"

if ! pactl list short sinks | awk -v name="$SINK_NAME" '$2 == name {found=1} END {exit !found}'; then
    printf '[CrateDigger] creating sink: %s\n' "$SINK_NAME"
    pactl load-module module-null-sink \
        sink_name="$SINK_NAME" \
        sink_properties="device.description=$SINK_DESCRIPTION" \
        >/dev/null || die "could not create sink '$SINK_NAME'"
fi

MONITOR="${SINK_NAME}.monitor"
pactl list short sources | awk -v name="$MONITOR" '$2 == name {found=1} END {exit !found}' \
    || die "sink monitor '$MONITOR' does not exist"

SOURCE="${SHAZAM_SOURCE:-}"
if [ -z "$SOURCE" ]; then
    SOURCE="$(pactl list short sources | awk '$2 ~ /^bluez_sink\..*\.a2dp_sink\.monitor$/ {print $2; exit}')"
fi

if [ -z "$SOURCE" ]; then
    die "no Bluetooth A2DP monitor source found (set SHAZAM_SOURCE to override)"
fi

pactl list short sources | awk -v name="$SOURCE" '$2 == name {found=1} END {exit !found}' \
    || die "source '$SOURCE' does not exist"

if pactl list short modules | grep -F "module-loopback" | grep -F "source=$SOURCE" | grep -F "sink=$SINK_NAME" >/dev/null; then
    printf '[CrateDigger] loopback already exists: %s -> %s\n' "$SOURCE" "$SINK_NAME"
    exit 0
fi

printf '[CrateDigger] creating loopback: %s -> %s\n' "$SOURCE" "$SINK_NAME"
pactl load-module module-loopback \
    source="$SOURCE" \
    sink="$SINK_NAME" \
    latency_msec="$LATENCY_MS" \
    >/dev/null || die "could not create loopback from '$SOURCE' to '$SINK_NAME'"

printf '[CrateDigger] audio setup ready: %s -> %s.monitor\n' "$SOURCE" "$SINK_NAME"
