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
- ⏳ Add an additional delay after a successful recognition
- 🔗 Optional `afterfound` shell hooks for automation

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

git clone https://github.com/hdp1972be-svg/youtube-shazam.git
cd youtube-shazam

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
cd youtube-shazam
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

### Live audio

```bash
./shazam --live --input pulse --device default
./shazam --live --input pulse --loop --interval 5 --delay 10
```

During live mode, `p` pauses/resumes, `n` discards the current cycle and starts a fresh recording, and `q` quits. `Ctrl-C` also aborts cleanly and restores the terminal's original settings. A real-time PCM level meter is displayed. Completely silent captures are not sent to Shazam.

### Live input options

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

## Qt wrapper

The CLI remains the primary interface, but CrateDigger also includes a thin **PyQt5** wrapper that puts the existing CLI inside a Qt window.

The wrapper does **not** reimplement or modify the recognition logic in `./shazam`. It runs the unchanged CLI in a pseudo-terminal (PTY), so the CLI still sees a real terminal and keeps its existing ANSI colours, progress updates, and live `p` / `n` controls.

Install PyQt5 if you want the wrapper:

```bash
python -m pip install PyQt5
```

Run it exactly like the CLI:

```bash
./cratedigger-qt.py --live --input pulse --device shazam_sink.monitor --loop
```

You can also pass a URL or any other normal CrateDigger arguments:

```bash
./cratedigger-qt.py 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00
```

The Qt window is deliberately just a terminal wrapper: the CLI remains the source of truth.

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

### JSON and CSV pipelines

For automation, JSON output is useful as a stable machine-readable representation of each recognition. A shell pipeline can then transform that JSON with normal Unix tools such as `jq`.

For example, keep a JSONL history of recognized tracks:

```ini
[HOOKS]
afterfound = shell exec sh -c 'printf "%s\\n" "$(jq -nc --arg artist "$SHAZAM_ARTIST" --arg title "$SHAZAM_RECORD" --arg genre "$SHAZAM_GENRE" --arg id "$SHAZAM_ID" --arg date "$SHAZAM_DATE" --arg url "$SHAZAM_URL" --arg youtubeid "$YOUTUBE_ID" '''{artist:$artist,title:$title,genre:$genre,id:$id,date:$date,url:$url,youtubeid:$youtubeid}''')" >> ~/.local/share/cratedigger.jsonl'
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
  "genre": "Dance"
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
{"title":"Example Song","artist":"Example Artist"}
```

With no match:

```json
{}
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
