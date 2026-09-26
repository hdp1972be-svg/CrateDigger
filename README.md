# YouTube Shazam

Identify music in a YouTube video (or a local media file) from a short audio segment — directly from the command line.

The tool combines **yt-dlp**, **FFmpeg/pydub**, and **ShazamIO**: it downloads the audio when given a YouTube URL, extracts the requested time window, and sends that short fragment to Shazam for recognition.

I built this because I couldn't find another small CLI tool that combines this particular workflow: **give it a YouTube URL, optionally point it at a timestamp, and identify the music playing there.**

## Features

- 🎵 Identify music directly from a YouTube URL
- 📁 Recognize a song from a local media file
- ⏱️ Start recognition at an exact timestamp
- ⌛ Choose how many seconds of audio to analyze
- 🔗 Automatically use a YouTube URL's `t=` timestamp when present
- 🦊 Use Firefox cookies through yt-dlp, so age/login/region-gated videos can work when your browser session has access
- 🤖 Human-readable output or machine-readable JSON
- 🧹 Temporary downloaded audio is cleaned up automatically

## Requirements

- Python 3
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) in `$PATH` for YouTube URLs
- FFmpeg
- Python packages:
  - `aiohttp`
  - `pydub`
  - `shazamio`

Check that yt-dlp is available:

```bash
which yt-dlp
```

Install the Python dependencies with:

```bash
python3 -m pip install aiohttp pydub shazamio
```

## Usage

### YouTube URL

```bash
./shazam.py 'https://www.youtube.com/watch?v=VIDEO_ID'
```

The default is to analyze a **15-second** fragment.

### Start at a timestamp

```bash
./shazam.py 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00
```

The `--time` option accepts:

- seconds: `90`
- minutes/seconds: `1:30`
- hours/minutes/seconds: `1:02:30`

If the URL contains a YouTube `t=` parameter, that timestamp is used automatically. An explicit `-t/--time` takes precedence.

### Change the analysis duration

```bash
./shazam.py 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00 -d 30
```

This analyzes 30 seconds starting at 10:00.

### Local media file

The same tool can work on a local audio/video file:

```bash
./shazam.py recording.mp3
```

The media file is not downloaded; the selected fragment is extracted locally.

### JSON output

For scripts and other automation:

```bash
./shazam.py 'https://www.youtube.com/watch?v=VIDEO_ID' --json
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
usage: shazam.py [-h] [-t TIME] [-d DURATION] [--json] [--keep-temp]
                 MEDIAFILE_OR_YOUTUBE_URL

positional arguments:
  MEDIAFILE_OR_YOUTUBE_URL
                        Local media file or YouTube URL

options:
  -h, --help            Show this help message and exit
  -t, --time TIME       Start time for recognition
  -d, --duration SECONDS
                        Number of seconds to analyze (default: 15)
  --json                Output recognition result as JSON
  --keep-temp           Keep the temporary downloaded audio
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
15 seconds
```

Longer fragments can be useful when the music is quiet or the selected point contains speech/noise.

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

The important part is that you don't have to manually download the video, cut out a fragment, open a music-recognition service, and feed it the audio. The whole operation is one command.

## Why?

There are plenty of ways to identify music *from a microphone* or from a file. What I wanted was the slightly different workflow:

```bash
youtube-shazam URL -t 12:43
```

> "What song is playing at 12:43?"

That makes it particularly useful for DJ sets, mixes, remixes, live recordings, long videos, playlists, interviews, and other YouTube content where the interesting track is only a small part of the video.

## License

See the repository license if one is added.
