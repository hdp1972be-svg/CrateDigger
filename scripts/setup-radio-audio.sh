#!/usr/bin/env bash
set -u

SINK_NAME="${SHAZAM_SINK_NAME:-shazam_sink}"
SINK_DESCRIPTION="${SHAZAM_SINK_DESCRIPTION:-ShazamSink}"
LATENCY_MS="${SHAZAM_LOOPBACK_LATENCY_MS:-100}"

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
need_cmd pgrep

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

SOURCE="${SHAZAM_AUDIO_SOURCE:-}"
if [ -z "$SOURCE" ]; then
    SOURCE="$(pactl list short sources | awk '$2 ~ /^bluez_sink\..*\.a2dp_sink\.monitor$/ {print $2; exit}')"
fi

if [ -z "$SOURCE" ]; then
    die "no Bluetooth A2DP monitor source found (set SHAZAM_AUDIO_SOURCE to override)"
fi

pactl list short sources | awk -v name="$SOURCE" '$2 == name {found=1} END {exit !found}' \
    || die "source '$SOURCE' does not exist"

FOUND_MODULE_ID=""
FOUND_LATENCY=""

while read -r MODULE_ID MODULE_NAME MODULE_ARGS; do
    [ "$MODULE_NAME" = "module-loopback" ] || continue

    case " $MODULE_ARGS " in
        *" source=$SOURCE "*)
            case " $MODULE_ARGS " in
                *" sink=$SINK_NAME "*)
                    FOUND_MODULE_ID="$MODULE_ID"
                    FOUND_LATENCY="$(printf '%s\n' "$MODULE_ARGS" | grep -oE '(^| )latency_msec=[^ ]+' | head -n1 | cut -d= -f2)"
                    break
                    ;;
            esac
            ;;
    esac
done < <(pactl list short modules)

if [ -n "$FOUND_MODULE_ID" ]; then
    if [ "$FOUND_LATENCY" = "$LATENCY_MS" ]; then
        printf '[CrateDigger] loopback already configured: %s -> %s (%sms)\n' \
            "$SOURCE" "$SINK_NAME" "$LATENCY_MS"
        exit 0
    fi

    printf '[CrateDigger] replacing loopback module %s: %s -> %s (%sms -> %sms)\n' \
        "$FOUND_MODULE_ID" "$SOURCE" "$SINK_NAME" "${FOUND_LATENCY:-unknown}" "$LATENCY_MS"

    pactl unload-module "$FOUND_MODULE_ID" \
        || die "could not unload existing loopback module $FOUND_MODULE_ID"
fi

printf '[CrateDigger] creating loopback: %s -> %s (%sms)\n' \
    "$SOURCE" "$SINK_NAME" "$LATENCY_MS"

pactl load-module module-loopback \
    source="$SOURCE" \
    sink="$SINK_NAME" \
    latency_msec="$LATENCY_MS" \
    >/dev/null || die "could not create loopback from '$SOURCE' to '$SINK_NAME'"

printf '[CrateDigger] audio setup ready: %s -> %s.monitor\n' "$SOURCE" "$SINK_NAME"


if [ "${SHAZAM_RADIO_WATCHER:-1}" = "1" ] && [ -n "${SHAZAM_PARENT_PID:-}" ] && kill -0 "$SHAZAM_PARENT_PID" 2>/dev/null; then
    SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
    WATCHER="$SCRIPT_DIR/watch-radio-audio.sh"
    if [ -f "$WATCHER" ] && ! pgrep -af "watch-radio-audio.sh $SHAZAM_PARENT_PID" >/dev/null 2>&1; then
        printf '[CrateDigger] starting Bluetooth audio reconnect watcher\n'
        nohup "$WATCHER" "$SHAZAM_PARENT_PID" >/tmp/cratedigger-radio-watch.log 2>&1 </dev/null &
    fi
fi
