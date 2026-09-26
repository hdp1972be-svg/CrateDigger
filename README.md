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

### What the dependencies do

Each dependency has a fairly specific job in the pipeline:

#### yt-dlp — obtaining the source audio

**yt-dlp** is responsible for retrieving the media from YouTube when the input is a YouTube URL.

It handles the YouTube-specific part — including format selection, extraction, and browser-cookie authentication. The script can therefore treat the downloaded result as an ordinary media file rather than having to implement YouTube's changing extraction mechanisms itself.

The tool also uses Firefox's existing browser cookies when requested, which is useful for videos where the browser session already has the required access.

> yt-dlp is only needed when the input is a YouTube URL. Local media files bypass it completely.

#### FFmpeg — decoding and converting media

**FFmpeg** is the media-processing engine underneath the audio extraction step.

It allows the project to work with different audio/video containers and codecs and to extract the small section of audio that is actually sent to Shazam.

For example, if you give the program a 90-minute video and ask for:

```bash
./shazam.py video.mp4 -t 42:17 -d 15
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

```python
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
