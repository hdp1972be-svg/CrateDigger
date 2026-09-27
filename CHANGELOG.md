# Changelog

All notable changes to CrateDigger are documented here.

## [0.5] - 2026-09-27

### Added

- Profile-selectable recognition engine chains via `engines = ...`.
- Virtual `[ENGINE <key>]` configuration sections.
- ACRCloud recognition provider support.
- AudD recognition provider support in the multi-provider dispatcher.
- Configurable `firstmatch` and `all` detection modes.
- Multi-provider fallback while reusing the same captured audio fragment.
- Provider-aware hook variable `%provider` / `$SHAZAM_PROVIDER`.
- Expanded hook placeholders for recognition metadata, audio files, source information and errors.
- Per-profile directories for retaining unmatched audio fragments.
- Automatic system-locale detection for terminal UI localization.
- Classic startup banner with version, release date and GitHub repository.
- Documentation for multi-provider recognition and hook expansion.

### Changed

- Renamed the application and configuration from the former Shazam-specific naming to CrateDigger.
- Recognition output identifies the engine/provider that produced a match.
- Provider no-match responses are handled separately from provider errors.
- Existing profiles explicitly select their recognition engine.
- Terminal UI strings were centralized for localization.
- Live-mode pause/quit handling was hardened.

### Fixed

- Correct handling of ACRCloud status code `0`.
- Correct handling of ACRCloud no-result responses.
- Successful ACRCloud responses without track data are treated as normal no-match results.
- ACRCloud recognition uses a short 8 kHz mono WAV sample and treats status `1001` as a normal no-match.
- Recognition fallback continues after provider no-match or provider error.
- All-provider no-match no longer incorrectly triggers the error path when a provider answered successfully.
- Restored correct terminal newline/control-character handling after localization refactoring.
- Preserved executable permissions on the main `cratedigger` entry point.
- Fixed localization and CLI-entry-point regressions.

### Recognition engines

Current provider architecture includes:

- Shazam
- ACRCloud
- AudD

The configuration is designed so additional providers can be added without changing the profile model.

### Notes

Version 0.5 marks the transition from a Shazam-specific recognizer to the CrateDigger multi-provider recognition architecture.
- Fixed `%provider` / `$SHAZAM_PROVIDER` propagation to the normal `afterfound` hook path.
- Added `%U<placeholder>` hook expansion for uppercase values.
