# YouTube Shazam

Identify music in a YouTube video (or a local media file) from a short audio segment — directly from the command line.

The tool combines **yt-dlp**, **FFmpeg/pydub**, and **ShazamIO**: it downloads audio when given a URL supported by yt-dlp, extracts the requested time window, and sends that short fragment to Shazam for recognition.

I built this because I couldn't find another small CLI tool that combines this particular workflow: **give it a YouTube URL, optionally point it at a timestamp, and identify the music playing there.**

## Features

- 🌐 Identify music from URLs supported by yt-dlp (YouTube, SoundCloud, Bandcamp, etc.)
- 📁 Recognize a song from a local media file
- ⏱️ Start recognition at an exact timestamp
- ⌛ Choose how many seconds of audio to analyze
- 🔗 Automatically use a YouTube URL's `t=` timestamp when present
- 🦊 Use Firefox cookies through yt-dlp, so age/login/region-gated videos can work when your browser session has access
- 🤖 Human-readable output or machine-readable JSON
- 🧹 Temporary downloaded audio is cleaned up automatically
- 🎙️ Listen to live audio through ALSA, PulseAudio, or JACK
- 🔁 Optionally repeat live recognition with a configurable interval
- ⏳ Add an additional delay after a successful recognition

## Requirements

- Python 3
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) in `$PATH` for online URLs
- FFmpeg
- Python packages:
  - `aiohttp`
  - `pydub`
  - `shazamio`

### What the dependencies do

Each dependency has a fairly specific job in the pipeline:

#### yt-dlp — obtaining the source audio

**yt-dlp** is responsible for retrieving the media from YouTube when the input is a YouTube URL.

It handles the YouTube-specific part — including format selection, extraction, and browser-cookie authentication. The script can therefore treat the downloaded result as an ordinary media file rather than having to implement YouTube's changing extraction mechanisms itself.

The tool also uses Firefox's existing browser cookies when requested, which is useful for videos where the browser session already has the required access.

> yt-dlp is only needed for online URLs. Local media files bypass it completely. Actual site support depends on what the installed yt-dlp version can extract.

#### FFmpeg — decoding and converting media

**FFmpeg** is the media-processing engine underneath the audio extraction step.

It allows the project to work with different audio/video containers and codecs and to extract the small section of audio that is actually sent to Shazam.

For example, if you give the program a 90-minute video and ask for:

```bash
./shazam video.mp4 -t 42:17 -d 15
```

the interesting part is the **15-second audio fragment around 42:17**, not the entire video.

FFmpeg is therefore the low-level media layer; it is not itself doing the music recognition.

#### pydub — convenient audio manipulation

**pydub** provides the higher-level Python interface used for manipulating the extracted audio.

Instead of dealing directly with FFmpeg's command-line syntax for every audio operation, the Python code can work with an audio segment and slice the requested time range.

In simplified terms:

```text
media file
    ↓
FFmpeg decoding
    ↓
pydub AudioSegment
    ↓
[start : start + duration]
    ↓
short audio sample
```

pydub therefore sits between the Python application and the underlying media conversion tools.

#### ShazamIO — music recognition

**ShazamIO** is the Python interface used to submit the selected audio fragment to Shazam's recognition service and retrieve the recognition result.

This is the component that answers the actual question:

> "What song is this?"

The result can contain information such as the track title and artist, which the CLI then displays or serializes as JSON.

#### aiohttp — asynchronous HTTP

**aiohttp** provides asynchronous HTTP functionality used by the ShazamIO stack.

The project does not use aiohttp as another independent music-recognition engine; it is part of the Python networking layer required for communicating with the recognition service.

### Dependency relationship

The whole stack can be viewed as:

```
                    YouTube URL
                         │
                         ▼
                      yt-dlp
                         │
                         ▼
                  downloaded media
                         │
                         ▼
                      FFmpeg
                         │
                         ▼
                    pydub audio
                         │
                         ▼
                selected audio fragment
                         │
                         ▼
                    ShazamIO
                         │
                         ▼
                      aiohttp
                         │
                         ▼
                 Shazam recognition
                         │
                         ▼
                   song + artist
```

For a local file, the YouTube/yt-dlp stage is simply skipped.

### Installing the dependencies

Install the system dependency first:

**Debian/Ubuntu:**

```bash
sudo apt install ffmpeg
```

Then install the Python packages:

```bash
python3 -m pip install aiohttp pydub shazamio
```

And make sure yt-dlp is available:

```bash
which yt-dlp
yt-dlp --version
ffmpeg -version
```

The important distinction is that **FFmpeg and yt-dlp are external executables**, while **aiohttp, pydub, and shazamio are Python packages**.

## Usage

### Online URL

Any HTTP(S) URL that the installed yt-dlp can extract can be used. For example:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID'
./shazam 'https://soundcloud.com/artist/track'
./shazam 'https://artist.bandcamp.com/track/example'
```

Actual site support depends on yt-dlp and the particular URL; the Shazam part is independent of the source.

The default is to analyze a **25-second** fragment.

### Start at a timestamp

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00
```

The `--time` option accepts:

- seconds: `90`
- minutes/seconds: `1:30`
- hours/minutes/seconds: `1:02:30`

If the URL contains a YouTube `t=` parameter, that timestamp is used automatically. An explicit `-t/--time` takes precedence.

### Change the analysis duration

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00 -d 30
```

This analyzes 30 seconds starting at 10:00.

### Local media file

The same tool can work on a local audio/video file:

```bash
./shazam recording.mp3
```

The media file is not downloaded; the selected fragment is extracted locally.

### Live audio

Use `--live` to listen to a system audio input instead of supplying a file or URL. FFmpeg provides the capture backend, with support for ALSA, PulseAudio, and JACK:

```bash
./shazam --live
```

Select the backend with `--input`:

```bash
./shazam --live --input alsa
./shazam --live --input pulse
./shazam --live --input jack
```

By default, one **25-second** capture is made and sent to Shazam.

The same duration option controls the capture length:

```bash
./shazam --live -d 15
```

With `--loop`, the tool keeps taking new captures. `--interval` controls the wait between captures:

```bash
./shazam --live -d 15 --interval 5 --loop
```

This gives you:

```text
capture 15s
    ↓
Shazam
    ↓
wait 5s
    ↓
capture 15s
    ↓
Shazam
    ↓
...
```

The interval is applied between live capture cycles, regardless of whether the previous capture produced a match.

#### Delay after a successful match

`--delay` adds an additional wait **after a song has been successfully recognized**. This is separate from `--interval`.

For example:

```bash
./shazam --live --input pulse --loop -d 25 --interval 5 --delay 10
```

results in:

```text
capture 25s
    ↓
Shazam
    ↓
song found
    ↓
wait 5s    ← --interval
    ↓
wait 10s   ← --delay
    ↓
capture 25s
    ↓
...
```

This is useful when repeatedly recognizing a continuous audio source and you want some extra time after a successful match before starting the next cycle.

The input source can be selected explicitly with `--device`. The exact name depends on the backend:

```bash
./shazam --live --input alsa --device hw:1
./shazam --live --input pulse --device default
./shazam --live --input jack --device system:capture_1
```

Press `Ctrl-C` to stop a looping session. You can also use `p` to pause/resume and `n` to discard the current cycle and start a fresh recording.

#
### Interactive live controls

Looping live recognition has keyboard controls directly from the terminal:

- **\`p\`** — pause/resume the current live capture
- **\`n\`** — discard the current capture or interrupt the current wait and start a fresh recording from 0s

The controls also work during \`--interval\` and \`--delay\` waits. The terminal is put into a temporary no-echo mode while live mode is running, so the keys do not have to be followed by Enter.

A live capture also displays a small real-time level meter based on the PCM audio actually received by FFmpeg:

\`\`\`text
Recording sec  24/25  [███████████████░░░░░] -12.1 dBFS  peak -1.6 dBFS
\`\`\`

If the captured PCM contains no non-zero samples, the program warns that the selected input may be silent or incorrect.

For example:

\`\`\`bash
./shazam --live --input pulse --device shazam_sink.monitor --loop
\`\`\`

Press **\`p\`** whenever you want to pause/resume capture, or **\`n\`** to throw away the current cycle and immediately begin a new one.

#### PulseAudio system-output capture

A convenient way to feed normal system audio into Shazam is to create a PulseAudio null sink and loop the desired monitor into it:

\`\`\`bash
pactl load-module module-null-sink \\
    sink_name=shazam_sink \\
    sink_properties=device.description=ShazamSink
\`\`\`

Then route a monitor source into that sink with \`module-loopback\`. The exact monitor name depends on the active PulseAudio device:

\`\`\`bash
pactl list short sources
\`\`\`

For example:

\`\`\`bash
pactl load-module module-loopback \\
    source=bluez_sink.CA_D5_01_BE_BA_6C.a2dp_sink.monitor \\
    sink=shazam_sink \\
    latency_msec=20
\`\`\`

Shazam can then listen to the null-sink monitor:

\`\`\`bash
./shazam --live --input pulse --device shazam_sink.monitor --loop
\`\`\`

This is useful when the audio you want to recognize is already playing through the normal system output.

### \`afterfound\` hooks

Recognized tracks can trigger an optional shell command through a \`.shazamrc\` configuration file.

The first existing configuration file from these locations is used:

\`\`\`text
./.shazamrc
~/.shazamrc
~/.config/shazam/shazamrc
~/.config/shazam/.shazamrc
\`\`\`

Example:

\`\`\`ini
[HOOKS]
afterfound = shell exec task add "%artist %record %id %date" +MUSIC
\`\`\`

The hook runs after a successful recognition. These placeholders are expanded:

| Placeholder | Environment variable | Value |
|---|---|---|
| \`%artist\` | \`SHAZAM_ARTIST\` | Recognized artist |
| \`%record\` | \`SHAZAM_RECORD\` | Recognized track title |
| \`%id\` | \`SHAZAM_ID\` | Shazam track key |
| \`%date\` | \`SHAZAM_DATE\` | Current date, ISO format |

The values are also exported as environment variables to the shell command. A leading \`shell exec \` is optional and is stripped before execution.

When a hook is configured, the active command is shown at startup:

\`\`\`text
🔗 afterfound hook actief: shell exec task add "%artist %record %id %date" +MUSIC
\`\`\`

After a successful recognition:

\`\`\`text
🔗 Executing afterfound hook...
\`\`\`

If the same artist/title/Shazam-ID combination is recognized again during the same running process, the hook is skipped to avoid creating duplicate actions. Restarting the program resets this duplicate-suppression state.

Hook failures do not invalidate an otherwise successful Shazam recognition; a non-zero hook exit status is reported as a warning.

This makes the CLI usable as a small automation bridge, for example:

\`\`\`text
audio source
    ↓
live capture
    ↓
Shazam recognition
    ↓
artist + title + Shazam ID
    ↓
afterfound hook
    ↓
Taskwarrior / script / any shell command
\`\`\`

## JSON output

For scripts and other automation:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' --json
```

Successful recognition returns:

```json
{"title":"Example Song","artist":"Example Artist"}
```

With no match, JSON output is:

```json
{}
```

## CLI reference

```
usage: shazam [-h] [-t TIME] [-d DURATION] [--json] [--keep-temp]
              [--live] [--input {alsa,pulse,jack}] [--interval INTERVAL]
              [--delay DELAY] [--device DEVICE] [--loop]
              [MEDIAFILE_OR_YOUTUBE_URL]

positional arguments:
  MEDIAFILE_OR_YOUTUBE_URL
                        Local media file or online URL

options:
  -h, --help            Show this help message and exit
  -t, --time TIME       Start time for recognition
  -d, --duration SECONDS
                        Number of seconds to analyze (default: 25)
  --json                Output recognition result as JSON
  --keep-temp           Keep the temporary downloaded audio
  --live                Listen to live audio
  --input {alsa,pulse,jack}
                        Live audio backend (default: alsa)
  --interval SECONDS    Wait between live captures (default: 5)
  --delay SECONDS       Wait after a found song (default: 0)
  --device DEVICE       Input source (default: default)
  --loop                Repeat live captures until interrupted
```

### `-t, --time`

Selects where recognition starts in the source.

Examples:

```text
-t 90
-t 1:30
-t 1:02:30
```

For YouTube URLs, a `t=` timestamp can also be read from the URL.

### `-d, --duration`

Controls the length of the audio fragment sent for recognition.

Default:

```text
25 seconds
```

Longer fragments can be useful when the music is quiet or the selected point contains speech/noise.

For live mode, the same option controls the length of each recording.

### `--interval`

In live loop mode, controls the wait between capture cycles.

For example:

```bash
./shazam --live --loop --interval 5
```

### `--delay`

In live loop mode, adds an additional wait after a successful song recognition.

For example:

```bash
./shazam --live --loop --interval 5 --delay 10
```

The two delays are independent: `--interval` is the normal pause between live capture cycles and runs first; `--delay` is added after a successful match.

### `--json`

Produces compact JSON instead of human-readable output, making the command convenient for shell scripts.

### `--keep-temp`

Normally temporary downloaded audio is removed after processing. This option keeps it, which is useful for debugging or inspecting exactly what was downloaded.

## Exit codes

The CLI uses distinct exit codes so it can also be used in shell scripts:

| Code | Meaning |
|---:|---|
| `0` | Song successfully recognized |
| `1` | No recognition / no matching song |
| `2` | Invalid usage or input |
| `3` | Processing/download/recognition error |

## How it works

For a YouTube URL the pipeline is roughly:

```
YouTube URL
    │
    ▼
yt-dlp --cookies-from-browser firefox
    │
    ▼
temporary audio file
    │
    ▼
extract selected time window
    │
    ▼
ShazamIO
    │
    ▼
title + artist
```

For live mode:

```
ALSA / PulseAudio / JACK
          │
          ▼
       FFmpeg
          │
          ▼
    16 kHz mono WAV
          │
          ▼
       ShazamIO
          │
          ▼
     title + artist
          │
          ├── --delay
          │
          ▼
     --interval
          │
          ▼
    next capture
```

The important part is that you don't have to manually download the video, cut out a fragment, open a music-recognition service, and feed it the audio. The whole operation is one command.

## Why?

Ever found a track in a long YouTube DJ mix, but don't know what it is?

Instead of playing the mix and holding your phone up to Shazam:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 47:23
```

That's it.

The tool grabs a short section around that timestamp and sends it to Shazam.

It's particularly handy for:

- 🎧 DJ mixes
- 🔊 radio mixes
- 🎵 long playlists
- 🪩 live sets
- 🎚️ remix compilations
- 📼 old recordings uploaded to YouTube

You can jump around a mix and query different timestamps without having to listen to the whole thing.

**Basically: Shazam, but for arbitrary points in a YouTube video.**

## License

See the repository license if one is added.


### Source URL / YouTube ID in Taskwarrior annotations

For URL-based recognition, the hook also exposes `%url` and `%youtubeid`. Taskwarrior cannot create a task and annotate it in the same command, so capture the created task ID and then annotate it.

```ini
[HOOKS]
afterfound = shell exec id=$(task add "%artist %record %id %date" +MUSIC | sed -n 's/.*Created task \\([0-9][0-9]*\\).*/\\1/p'); [ -n "$id" ] && task "$id" annotate "source: %url youtubeid: %youtubeid"
```

Taskwarrior's `annotate` command adds a note to an existing task; annotations are searchable text.

Available hook placeholders:

- `%artist` — Shazam artist
- `%record` — Shazam title
- `%id` — Shazam track ID
- `%date` — recognition date
- `%url` — original source URL
- `%youtubeid` — YouTube video ID

For live/PulseAudio recognition, `%url` and `%youtubeid` are empty.
