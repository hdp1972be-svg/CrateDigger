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

### What the dependencies do

#### yt-dlp — obtaining online media

**yt-dlp** is responsible for retrieving media from supported online URLs.

It handles source-specific extraction, format selection, and browser-cookie authentication. The script can therefore treat the downloaded result as an ordinary media file rather than implementing each site's changing extraction mechanisms itself.

> yt-dlp is only needed for online URLs. Local media files and live audio bypass it completely. Actual site support depends on what the installed yt-dlp version can extract.

#### FFmpeg — decoding and converting media

**FFmpeg** is the media-processing engine underneath the audio extraction step.

It allows the project to work with different audio/video containers and codecs and to extract the small section of audio that is actually sent to Shazam.

#### pydub — convenient audio manipulation

**pydub** provides the higher-level Python interface used for manipulating extracted audio and selecting the requested time range.

#### ShazamIO — music recognition

**ShazamIO** is the Python interface used to submit the selected audio fragment to Shazam's recognition service and retrieve the recognition result.

#### aiohttp — asynchronous HTTP

**aiohttp** provides asynchronous HTTP functionality used by the ShazamIO stack.

### Dependency relationship

For online media:

```
                    Online URL
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
                 Shazam recognition
                         │
                         ▼
                   song + artist
```

For local media, the yt-dlp stage is skipped. For live audio, FFmpeg captures directly from ALSA, PulseAudio, or JACK.

### Installing the dependencies

**Debian/Ubuntu:**

```bash
sudo apt install ffmpeg
```

Then:

```bash
python3 -m pip install aiohttp pydub shazamio
```

And make sure yt-dlp is available:

```bash
which yt-dlp
yt-dlp --version
ffmpeg -version
```

## Usage

### Online URLs

Any HTTP(S) URL that the installed yt-dlp can extract can be used. For example:

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

The `--time` option accepts:

- seconds: `90`
- minutes/seconds: `1:30`
- hours/minutes/seconds: `1:02:30`

If the URL contains a YouTube `t=` parameter, that timestamp is used automatically. An explicit `-t/--time` takes precedence.

### Local media file

The same tool works on local audio/video files:

```bash
./shazam recording.mp3
```

The media file is not downloaded; the selected fragment is extracted locally.

### Live audio

Use `--live` to listen to a system audio input:

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

With `--loop`, the tool keeps taking new captures:

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

#### Delay after a successful match

`--delay` adds an additional wait after a song has been successfully recognized:

```bash
./shazam --live --input pulse --loop -d 25 --interval 5 --delay 10
```

The input source can be selected explicitly with `--device`:

```bash
./shazam --live --input alsa --device hw:1
./shazam --live --input pulse --device default
./shazam --live --input jack --device system:capture_1
```

Press `Ctrl-C` to stop. During live mode, `p` pauses/resumes and `n` discards the current cycle and starts a fresh recording.

### Interactive live controls

Looping live recognition has keyboard controls directly from the terminal:

- **`p`** — pause/resume the current live capture
- **`n`** — discard the current capture or interrupt the current wait and start a fresh recording from 0s

The controls also work during `--interval` and `--delay` waits.

A live capture displays a real-time level meter based on the PCM audio actually received by FFmpeg:

```text
Recording sec  24/25  [███████████████░░░░░] -12.1 dBFS  peak -1.6 dBFS
```

If the captured PCM contains no non-zero samples, the program does not send the silent recording to Shazam.

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

Route the desired monitor into the null sink with `module-loopback`:

```bash
pactl load-module module-loopback \
    source=bluez_sink.CA_D5_01_BE_BA_6C.a2dp_sink.monitor \
    sink=shazam_sink \
    latency_msec=20
```

The source shown above is an example; the monitor name depends on the active PulseAudio device.

Shazam can then listen to the null-sink monitor:

```bash
./shazam --live --input pulse --device shazam_sink.monitor --loop
```

This is useful when the audio you want to recognize is already playing through the normal system output.

## `afterfound` hooks

Recognized tracks can trigger an optional shell command through a `.shazamrc` configuration file.

The first existing configuration file from these locations is used:

```text
./.shazamrc
~/.shazamrc
~/.config/shazam/shazamrc
~/.config/shazam/.shazamrc
```

Example:

```ini
[HOOKS]
afterfound = shell exec task add "%artist %record %id %date" +MUSIC
```

Available placeholders:

| Placeholder | Environment variable | Value |
|---|---|---|
| `%artist` | `SHAZAM_ARTIST` | Recognized artist |
| `%record` | `SHAZAM_RECORD` | Recognized track title |
| `%id` | `SHAZAM_ID` | Shazam track key |
| `%date` | `SHAZAM_DATE` | Current date, ISO format |
| `%url` | `SHAZAM_URL` | Original source URL |
| `%youtubeid` | `YOUTUBE_ID` | YouTube video ID, when applicable |

The values are also exported as environment variables to the shell command. A leading `shell exec ` is optional.

If the same artist/title/Shazam-ID combination is recognized again during the same running process, the hook is skipped to avoid duplicate actions.

Hook failures do not invalidate an otherwise successful Shazam recognition; a non-zero hook exit status is reported as a warning.

## JSON output

For scripts and other automation:

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

## How it works

For an online URL:

```
Online URL
    │
    ▼
yt-dlp
    │
    ▼
temporary media
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

The important part is that you don't have to manually download media, cut out a fragment, open a music-recognition service, and feed it the audio. The whole operation is one command.

## Why?

Ever found a track in a long DJ mix, livestream, playlist, or random online video, but don't know what it is?

Instead of playing the source and holding your phone up to Shazam:

```bash
./shazam 'https://www.youtube.com/watch?v=VIDEO_ID' -t 47:23
```

That's it.

It's particularly handy for:

- 🎧 DJ mixes
- 🔊 radio mixes
- 🎵 long playlists
- 🪩 live sets
- 🎚️ remix compilations
- 📼 old recordings
- 🌐 random online media

**Basically: Shazam for crate digging — arbitrary points in online media, local files, or whatever is currently playing.**

## License

See the repository license if one is added.

### Source URL / YouTube ID in Taskwarrior annotations

For URL-based recognition, the hook also exposes `%url` and `%youtubeid`. Taskwarrior cannot create a task and annotate it in the same command, so capture the created task ID and then annotate it.

```ini
[HOOKS]
afterfound = shell exec id=$(task add "%artist %record %id %date" +MUSIC | sed -n 's/.*Created task \([0-9][0-9]*\).*/\1/p'); [ -n "$id" ] && task "$id" annotate "source: %url youtubeid: %youtubeid"
```

Taskwarrior's `annotate` command adds a note to an existing task; annotations are searchable text.

For live/PulseAudio recognition, `%url` and `%youtubeid` are empty.
