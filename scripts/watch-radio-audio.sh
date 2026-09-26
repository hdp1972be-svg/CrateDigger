#!/usr/bin/env bash
set -u

PARENT_PID="${1:-}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SETUP="$SCRIPT_DIR/setup-radio-audio.sh"

[ -n "$PARENT_PID" ] || exit 0
kill -0 "$PARENT_PID" 2>/dev/null || exit 0

while kill -0 "$PARENT_PID" 2>/dev/null; do
    EVENT="$(pactl subscribe 2>/dev/null | grep -m1 -E 'on (sink|source)' || true)"
    [ -n "$EVENT" ] || {
        sleep 1
        continue
    }

    sleep 1
    kill -0 "$PARENT_PID" 2>/dev/null || exit 0

    SHAZAM_PARENT_PID="$PARENT_PID"     SHAZAM_RADIO_WATCHER=0         bash "$SETUP" >/tmp/cratedigger-radio-watch-setup.log 2>&1 || true
done
