# CrateDigger

Identify music from online media, live audio, or local media from a short audio segment — directly from the command line.

The tool combines **yt-dlp**, **FFmpeg/pydub**, and **ShazamIO**: it retrieves online media when given a URL supported by yt-dlp, extracts the requested time window, and sends that short fragment to Shazam for recognition.

I built this because I wanted a small CLI tool for **crate digging across online media, local files, and live audio** — give it a source, optionally point it at a timestamp, and identify the music playing there.

## Supported sources

CrateDigger can recognize music from:

- ▶️ **YouTube**
- ☁️ **SoundCloud**
- 🏕️ **Bandcamp**
- 📸 **Instagram** media URLs supported by yt-dlp
- 🎙️ **Live audio** via ALSA, PulseAudio, or JACK
- 📁 **Local audio/video files**

Online-source support is provided by **yt-dlp**, so the exact URLs that work depend on the installed yt-dlp version and the particular media URL. CrateDigger itself is source-agnostic once the media has been obtained.

## Features

- 🌐 Identify music from URLs supported by yt-dlp
- 📁 Recognize a song from a local media file
- 🎙️ Listen to live audio through ALSA, PulseAudio, or JACK
- ⏱️ Start recognition at an exact timestamp
- ⌛ Choose how many seconds of audio to analyze
- 🔗 Automatically use a YouTube URL's `t=` timestamp when present
- 🦊 Use Firefox cookies through yt-dlp, so age/login/region-gated media can work when your browser session has access
- 🤖 Human-readable output or machine-readable JSON
- 🧹 Temporary downloaded audio is cleaned up automatically
- 🔁 Optionally repeat live recognition with a configurable interval
- 📂 Batch-recognize all supported media files in a directory with `--recursive`
- 👀 Watch a directory for new or changed media files with `--watch`
- 📊 Expose Shazam's recognition score as `confidence` when provided
- ⏳ Add an additional delay after a successful recognition
- 🪝 Lifecycle shell hooks: `startup`, `beforefound`, `afterfound`, `nomatch`, and `error`
- ⚙️ Named profiles with profile-specific settings and hook overrides
- 📋 Inspect available profiles with `--list-profiles`
- 🐛 Debug live captures with `--debug`, keeping temporary WAV fragments in `/tmp`

## Requirements

- Python 3
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) in `$PATH` for online URLs
- FFmpeg
- Python packages:
  - `aiohttp`
  - `pydub`
  - `shazamio`

### Easy install on Ubuntu/Debian

The simplest setup is a small virtual environment:

```bash
sudo apt install python3 python3-venv ffmpeg

git clone https://github.com/hdp1972be-svg/CrateDigger.git
cd CrateDigger

python3 -m venv .venv
. .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install yt-dlp aiohttp pydub shazamio
```

Then run:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID'
```

For later sessions:

```bash
cd CrateDigger
. .venv/bin/activate
./shazam ...
```

If you only use local files, `yt-dlp` is not required. ALSA is available through the normal Linux audio stack; PulseAudio and JACK require their respective audio systems to be installed/configured separately.

## Usage

### Online URLs

Any HTTP(S) URL that the installed yt-dlp can extract can be used:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID'
./shazam 'https://soundcloud.com/artist/track'
./shazam 'https://artist.bandcamp.com/track/example'
```

Instagram media URLs are supported when the installed yt-dlp version supports the particular URL.

The default is to analyze a **25-second** fragment.

### Start at a timestamp

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00
```

The `--time` option accepts seconds, `MM:SS`, or `HH:MM:SS`. If the URL contains a YouTube `t=` parameter, that timestamp is used automatically. An explicit `-t/--time` takes precedence.

### Local media file

```bash
./shazam recording.mp3
```

Local media bypasses yt-dlp.

### Recursive batch mode

Recognize every supported media file in a directory:

```bash
./shazam --recursive ~/Music/unknown
```

Subdirectories are included automatically by `--recursive`.

### Watch mode

Watch a directory continuously and recognize newly appearing or changed media files:

```bash
./shazam --watch ~/Music/incoming
```

Combine it with `--recursive` to watch subdirectories too:

```bash
./shazam --watch ~/Music/incoming --recursive
```

Press `Ctrl-C` to stop watching.

### Live audio

```bash
./shazam --live --input pulse --device default
./shazam --live --input pulse --loop --interval 5 --delay 10
```

During live mode, `p` pauses/resumes, `n` discards the current cycle and starts a fresh recording, and `q` quits. `Ctrl-C` also aborts cleanly and restores the terminal's original settings. A real-time PCM level meter is displayed. Completely silent captures are not sent to Shazam.

#### Debugging live captures

Use `--debug` when diagnosing capture or recognition problems:

```bash
./shazam --live --input pulse --device shazam_sink.monitor --debug
```

Debug mode keeps temporary live WAV fragments in `/tmp` instead of deleting them after recognition and prints their paths for inspection. Without `--debug`, temporary live fragments are cleaned up normally.
## Live input options

The `--input` option selects the FFmpeg capture backend:

| Backend | `--input` | `--device` example | Typical use |
|---|---|---|---|
| ALSA | `alsa` | `default` or `hw:1,0` | Direct sound-card / ALSA capture |
| PulseAudio | `pulse` | `default`, `shazam_sink.monitor` | Desktop audio, Bluetooth monitors, Pulse sources |
| JACK | `jack` | JACK input/client name | JACK audio graph |

Examples:

```bash
# ALSA
./shazam --live --input alsa --device default
./shazam --live --input alsa --device hw:1,0

# PulseAudio
./shazam --live --input pulse --device default
./shazam --live --input pulse --device shazam_sink.monitor

# JACK
./shazam --live --input jack --device system:capture_1
```

`--device` is passed directly to FFmpeg as the input device/source name. The exact names available therefore depend on the audio system and its current configuration. If you are unsure what to use, inspect the devices/sources with the tools provided by your audio stack (for example `pactl list short sources` for PulseAudio).

#### PulseAudio system-output capture

A convenient way to feed normal system audio into Shazam is to create a PulseAudio null sink:

```bash
pactl load-module module-null-sink \
    sink_name=shazam_sink \
    sink_properties=device.description=ShazamSink
```

Then list the available monitor sources:

```bash
pactl list short sources
```

Route the desired monitor into the null sink:

```bash
pactl load-module module-loopback \
    source=bluez_sink.CA_D5_01_BE_BA_6C.a2dp_sink.monitor \
    sink=shazam_sink \
    latency_msec=20
```

The BlueZ monitor name above is an example; the actual name depends on the active device.

Then:

```bash
./shazam --live --input pulse --device shazam_sink.monitor --loop
```

## Lifecycle hooks

CrateDigger supports five lifecycle events:

- `startup` — runs once when CrateDigger starts, before audio/network work
- `beforefound` — runs after Shazam identifies a track, immediately before `afterfound`
- `afterfound` — runs after a new recognition; repeated identical matches are suppressed
- `nomatch` — runs when Shazam responds successfully but does not identify the fragment
- `error` — runs for recognition/network errors

The `startup` hook is useful for preparing external resources before capture starts, such as PulseAudio sinks and loopbacks. Profile hooks override global `[HOOKS]` values for the same event.

## `afterfound` hooks

Recognized tracks can trigger an optional shell command through a `.shazamrc` configuration file.

The first existing configuration file from these locations is used:

```text
./.shazamrc
~/.shazamrc
~/.config/shazam/shazamrc
~/.config/shazam/.shazamrc
```

### Example: dump every discovered track into a Taskwarrior MUSIC queue

One deliberately simple way to use CrateDigger is to let the hook turn every newly recognized track into a Taskwarrior task tagged `MUSIC`:

```ini
[HOOKS]
afterfound = shell exec task add "%artist %record %id %date" +MUSIC
```

That's it.

For example, a live crate-digging session can produce:

```text
Created task 1253.
Created task 1254.
Created task 1255.
...
```

and:

```bash
task +MUSIC
```

becomes your music-discovery queue.

This keeps the responsibilities nicely separated:

```text
CrateDigger
    ↓
recognize track
    ↓
afterfound hook
    ↓
Taskwarrior +MUSIC
    ↓
your downloader / acquisition script
    ↓
actual audio crate
```

CrateDigger does not need to know how you ultimately acquire or organize the audio. The hook is just the bridge.

That's also a useful example of why `afterfound` is deliberately a shell hook rather than hard-coded Taskwarrior integration: **Unix plumbing stays Unix plumbing.**

The recognition score is also available to hooks when Shazam provides one:

- `%confidence` — recognition score
- `$SHAZAM_CONFIDENCE` — the same value as an environment variable
- `%source` / `$SHAZAM_SOURCE` — original source (file path, URL, or live input)
- `%sourcetype` / `$SHAZAM_SOURCE_TYPE` — `file`, `url`, or `live`

JSON output includes the same value as `confidence` when available.

### Hooks

Hooks are configured in `.shazamrc` under `[HOOKS]`. The four lifecycle events are:

- `beforefound` — runs after Shazam has identified a track, immediately before `afterfound`
- `afterfound` — runs after a new recognition; repeated identical consecutive matches are suppressed
- `nomatch` — runs when Shazam successfully responds but does not identify the fragment
- `error` — runs for recognition/network errors

All hooks receive the common environment variables where applicable:

- `$SHAZAM_ARTIST`
- `$SHAZAM_RECORD`
- `$SHAZAM_ID`
- `$SHAZAM_GENRE`
- `$SHAZAM_CONFIDENCE`
- `$SHAZAM_DATE`
- `$SHAZAM_URL`
- `$YOUTUBE_ID`
- `$SHAZAM_SOURCE`
- `$SHAZAM_SOURCE_TYPE`
- `$SHAZAM_ERROR` — error text for `error`
- `$SHAZAM_EXIT_CODE` — relevant exit code for `nomatch`/`error`

The command may use placeholders such as `%artist`, `%record`, `%confidence`, `%source`, `%sourcetype`, `%error`, and `%exitcode`; they are expanded through the corresponding environment variables.

Example:

```ini
[HOOKS]
beforefound = shell exec printf 'candidate: %s\\n' "$SHAZAM_ARTIST - $SHAZAM_RECORD"
afterfound = shell exec task add "%artist %record %id %date" +MUSIC
nomatch = shell exec logger -t cratedigger "no match: $SHAZAM_SOURCE"
error = shell exec logger -t cratedigger "error $SHAZAM_EXIT_CODE: $SHAZAM_ERROR"
```

A profile can override individual hooks. The profile hook takes precedence over the global `[HOOKS]` value:

```ini
[PROFILE radio]
afterfound = shell exec ~/bin/radio-found.sh
nomatch = shell exec ~/bin/radio-miss.sh
```
### Profiles

Profiles can be defined in `.shazamrc`. The built-in `default` profile keeps the current command-line defaults, so existing behaviour is unchanged.

```ini
[PROFILE default]
duration = 25
interval = 5
delay = 0
input = alsa
device = default
loop = false
json = false
keep_temp = false
live = false
recursive = false

[PROFILE radio]
live = true
input = pulse
device = shazam_sink.monitor
duration = 20
interval = 10
loop = true
```

Use a profile with:

```bash
./shazam --profile radio
```

Inspect configured profiles and their effective settings with:

```bash
./shazam --list-profiles
```

Explicit command-line options still override the profile values.

### Automated PulseAudio/Bluetooth capture

CrateDigger includes `scripts/setup-radio-audio.sh` for preparing a PulseAudio capture path before live recognition. The script:

1. Creates a `shazam_sink` null sink when needed.
2. Finds a Bluetooth A2DP monitor source unless one is explicitly configured.
3. Creates a PulseAudio loopback from that monitor into `shazam_sink`.
4. Uses **100 ms loopback latency by default**.
5. Reuses an existing matching loopback when its latency is already correct.
6. Recreates the matching loopback when its latency differs.

The 100 ms default is intentional: lower loopback latency can produce unstable/noisy capture on some PulseAudio/Bluetooth setups even when direct recording from the Bluetooth monitor is clean.

An automatic radio profile can therefore be as simple as:

```ini
[PROFILE radio]
startup = shell exec bash scripts/setup-radio-audio.sh
live = true
input = pulse
device = shazam_sink.monitor
duration = 20
interval = 10
delay = 5
loop = true
```

The setup script accepts these environment variables:

- `SHAZAM_SINK_NAME` — null-sink name; default `shazam_sink`
- `SHAZAM_SINK_DESCRIPTION` — sink description; default `ShazamSink`
- `SHAZAM_LOOPBACK_LATENCY_MS` — loopback latency; default `100`
- `SHAZAM_AUDIO_SOURCE` — explicit PulseAudio source override

The source override deliberately uses `SHAZAM_AUDIO_SOURCE`; `SHAZAM_SOURCE` is reserved by CrateDigger for the original recognition source exposed to hooks.

Manual setup is also possible:

```bash
pactl load-module module-null-sink \
    sink_name=shazam_sink \
    sink_properties=device.description=ShazamSink

pactl list short sources

pactl load-module module-loopback \
    source=bluez_sink.CA_D5_01_BE_BA_6C.a2dp_sink.monitor \
    sink=shazam_sink \
    latency_msec=100
```

Then capture from `shazam_sink.monitor`:

```bash
./shazam --live --input pulse --device shazam_sink.monitor --loop
```

## JSON and CSV pipelines

For automation, JSON output is useful as a stable machine-readable representation of each recognition. A shell pipeline can then transform that JSON with normal Unix tools such as `jq`.

For example, keep a JSONL history of recognized tracks:

```ini
[HOOKS]
afterfound = shell exec sh -c 'printf "%s\\n" "$(jq -nc --arg artist "$SHAZAM_ARTIST" --arg title "$SHAZAM_RECORD" --arg genre "$SHAZAM_GENRE" --arg id "$SHAZAM_ID" --arg date "$SHAZAM_DATE" --arg url "$SHAZAM_URL" --arg youtubeid "$YOUTUBE_ID" --arg source "$SHAZAM_SOURCE" --arg sourcetype "$SHAZAM_SOURCE_TYPE" '''{artist:$artist,title:$title,genre:$genre,id:$id,date:$date,url:$url,youtubeid:$youtubeid,source:$source,source_type:$sourcetype}''')" >> ~/.local/share/cratedigger.jsonl'
```

JSONL is preferable to appending separate JSON objects to one `.json` file because every line remains an independent valid JSON value.

To turn recognition data into CSV, `jq` can produce properly quoted CSV fields:

```bash
jq -r '[.artist,.title,.genre,.id,.date,.url,.youtubeid] | @csv'
```

For example, given a JSON record:

```json
{
  "artist": "Example Artist",
  "title": "Example Song",
  "genre": "Dance",
  "id": "123456789",
  "date": "2026-09-26",
  "url": "https://example.com/source",
  "youtubeid": "VIDEO_ID"
}
```

the same pattern can be used to build a CSV file, with `@csv` taking care of commas and quoting.

The JSON output from CrateDigger also reports the recognition status:

```json
{
  "status": "found",
  "title": "Example Song",
  "artist": "Example Artist",
  "genre": "Dance",
  "source": "https://example.com/source",
  "source_type": "url"
}
```

When Shazam responds successfully but does not identify the fragment:

```json
{
  "status": "no_match"
}
```

The process exit status is also useful in scripts:

```text
0   track found
1   no match
2   network / operational error
130 user abort (Ctrl-C or q)
```

### Terminal cleanup

Live mode temporarily puts the terminal into cbreak/noecho mode so that single-key controls work. CrateDigger saves the original tty settings and restores them when live mode exits, including when `Ctrl-C` interrupts an active recording or wait. This prevents the shell from being left with broken input/echo settings.

### Other examples: SQL, databases, HTTP, or your own script

The hook is intentionally **storage-agnostic**. Taskwarrior is just one possible consumer. Since the hook is a normal shell command, you can feed recognition results into SQLite, PostgreSQL, another CLI database tool, an HTTP endpoint, or a script of your own.

For example, a simple SQLite ingest could look like:

```bash
sqlite3 music.db \
  "INSERT INTO tracks (artist,title,shazam_id,found_at) \
   VALUES ('$SHAZAM_ARTIST','$SHAZAM_RECORD','$SHAZAM_ID','$SHAZAM_DATE');"
```

PostgreSQL works just as naturally:

```bash
psql music \
  -c "INSERT INTO tracks (artist,title,shazam_id,found_at) \
      VALUES ('$SHAZAM_ARTIST','$SHAZAM_RECORD','$SHAZAM_ID','$SHAZAM_DATE');"
```

Or send the result to another local or network service:

```bash
curl -X POST http://localhost:8080/tracks \
  -d "artist=$SHAZAM_ARTIST&title=$SHAZAM_RECORD&id=$SHAZAM_ID"
```

For anything more involved, point the hook at your own script:

```ini
[HOOKS]
afterfound = shell exec ~/.local/bin/cratedigger-found
```

A script can then decide whether to update Taskwarrior, ingest SQL, call an API, download media, or do several things at once.

For database ingestion, prefer parameterized/prepared statements in your own application code rather than constructing SQL from shell-expanded recognition strings. Track titles and artist names are arbitrary external data and can contain quotes or other characters that are significant to SQL.

### Source URL and YouTube ID

For URL-based recognition, the hook also exposes:

- `%url` — original source URL
- `%youtubeid` — extracted YouTube video ID, when applicable
- `%artist` — recognized artist
- `%record` — recognized title
- `%id` — Shazam track key
- `%date` — current date

For example:

```ini
[HOOKS]
afterfound = shell exec task add "%artist %record %id %date" +MUSIC
```

The values are also exported as environment variables to the shell command.

If the same artist/title/Shazam-ID combination is recognized again during the same running process, the hook is skipped to avoid duplicate actions.

Hook failures do not invalidate an otherwise successful Shazam recognition; a non-zero hook exit status is reported as a warning.

## JSON output

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' --json
```

Successful recognition returns:

```json
{
  "status": "found",
  "title": "Example Song",
  "artist": "Example Artist",
  "genre": "Dance",
  "confidence": 0.94
}
```

The `confidence` field is included only when Shazam supplies a score.

With no match:

```json
{"status":"no_match"}
```

## How it works

For online media:

```text
Online URL → yt-dlp → media → FFmpeg/pydub → ShazamIO → track
```

For live audio:

```text
ALSA / PulseAudio / JACK → FFmpeg → PCM WAV → ShazamIO → track
```

The important part is that you don't have to manually download media, cut out a fragment, open a music-recognition service, and feed it the audio. The whole operation is one command.

## Why?

Ever found a track in a long DJ mix, livestream, playlist, or random online video, but don't know what it is?

Instead of playing the source and holding your phone up to Shazam:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 47:23
```

That's it.

It's particularly handy for DJ mixes, radio mixes, live sets, remix compilations, old recordings, and random online media.

**Basically: Shazam for crate digging — arbitrary points in online media, local files, or whatever is currently playing.**

## License

See the repository license if one is added.
