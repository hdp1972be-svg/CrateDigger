# Recognition providers

CrateDigger uses a provider-neutral recognition pipeline. A profile selects one or more virtual engine keys with:

```ini
[PROFILE default]
engines = shazam, acrcloud, audd, chromaprint
detection_mode = firstmatch
```

Each `[ENGINE <key>]` section maps a virtual engine key to a provider and contains provider-specific settings.

## Providers

### Shazam

Uses the Shazam recognition implementation already integrated into CrateDigger.

```ini
[ENGINE shazam]
provider = shazam
```

### ACRCloud

Uses the ACRCloud Identify API.

```ini
[ENGINE acrcloud]
provider = acrcloud
host = your-acrcloud-host
access_key = your-access-key
access_secret = your-access-secret
```

### AudD

Uses the AudD music recognition API.

```ini
[ENGINE audd]
provider = audd
api_token = your-audd-api-token
```

### Chromaprint / AcoustID

Generates a local Chromaprint fingerprint with `fpcalc` and looks it up through AcoustID.

```ini
[ENGINE chromaprint]
provider = chromaprint
client = your-acoustid-application-api-key
```

The `fpcalc` executable must be installed and available in `$PATH`.

**Important:** AcoustID is intended for identifying full or sufficiently long audio files. CrateDigger normally works with short recognition fragments, so this provider should be considered optional for short live recognition.

## Detection modes

### `firstmatch`

The default behavior. Providers are queried in profile order and recognition stops after the first provider returns a match.

### `all`

Every configured provider is queried with the same captured audio fragment. Each successful provider result is reported separately and triggers the found hooks separately.

## Fallback behavior

1. A provider match is recorded.
2. A provider no-match continues to the next provider.
3. A provider error also allows the next provider to be tried.
4. If at least one provider answered successfully but none matched, the overall result is a normal no-match.
5. If no provider answered successfully and errors occurred, CrateDigger enters the error path.

## Hooks

The provider is exposed to hooks as `%provider` and `$SHAZAM_PROVIDER`.

Uppercase expansion is available with `%U`, for example:

```ini
afterfound = shell exec task add "%Uartist - %Urecord | %Uprovider ID: %id" +MUSIC
```

## Adding a provider

A new provider should implement a provider-specific recognition function, return the normalized `{"track": ...}` structure, return `{}` for a normal no-match, raise exceptions for actual provider failures, and be added to `herken_met_engine()`. Update the configuration, docs and CHANGELOG when the provider is user-visible.
