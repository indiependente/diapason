# Diapason

Native macOS music player for a [Jellyfin](https://jellyfin.org) server. A replacement for Feishin with playback controls that integrate with macOS Now Playing (Control Center, media keys, AirPods).

## Requirements

- macOS 26+
- Xcode 26+
- Homebrew tools: `xcodegen`, `xcbeautify`, `swiftlint`, `swiftformat`

```sh
brew install xcodegen xcbeautify swiftlint swiftformat
```

## Common commands

| Command | What it does |
|---|---|
| `make gen` | Regenerate `Diapason.xcodeproj` from `project.yml` |
| `make build` | Build the app |
| `make run` | Build and launch `Diapason.app` |
| `make test` | Run the unit tests (`DiapasonTests`) |
| `make test-e2e` | Run the XCUITest flow against a real server (see below) |
| `make lint` | Run SwiftLint with `--strict` |
| `make format` | Run SwiftFormat in place |
| `make icons` | Regenerate the icon set from `Resources/AppIcon.png` |
| `make install` | Copy the built app to `/Applications/` |
| `make clean` | Wipe the generated project and build artifacts |

The `.xcodeproj` is generated and gitignored. Edit `project.yml`, then run `make gen`.

## Features

- Sign in to a Jellyfin server. The token is stored in the macOS Keychain.
- Browse albums and playlists, with artwork and search.
- Play, pause, next, previous, seek, and volume. Double-click a track to play from there.
- Now Playing integration: Control Center, media keys, and the playback position scrubber.
- Playback reports to the server, so play counts and history update.

FLAC, MP3, AAC, ALAC, WAV, and AIFF play directly. The server transcodes other formats to AAC.

## End-to-end test

`make test-e2e` signs in through the UI, plays the first track of the first playlist, and checks that the server session shows the same track. It needs a reachable server:

```sh
DIAPASON_TEST_SERVER=http://192.168.0.14:8096 \
DIAPASON_TEST_USER=jellyfin \
DIAPASON_TEST_PASSWORD="$(cat ~/jellyfin_pass.txt)" \
make test-e2e
```

Without these variables the test is skipped.

## Layout

```
Sources/Diapason/
  Jellyfin/   REST client, credentials, Keychain, Library (server state)
  Player/     PlayQueue, Player (AVPlayer), NowPlaying (MediaPlayer bridge)
  Models/     Track, MusicCollection, SidebarItem
  Views/      RootView, SidebarView, AlbumsView, TrackListView, PlayerBar, SignInView, SettingsView
Tests/DiapasonTests/     unit tests (Swift Testing, ViewInspector)
Tests/DiapasonUITests/   XCUITest end-to-end flow
```
