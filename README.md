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
| `make archive` | Archive the app to `build/Diapason.xcarchive` |
| `make dmg` | Export a Developer ID-signed app and build `build/Diapason.dmg` |
| `make dmg-unsigned` | Build a DMG from the ad-hoc signed archive, for personal use |
| `make appcast` | Sign the DMG and write `build/appcast.xml` for Sparkle |
| `make release` | `dmg` + `appcast` |
| `make clean` | Wipe the generated project and build artifacts |

The `.xcodeproj` is generated and gitignored. Edit `project.yml`, then run `make gen`.

## Features

- Sign in to a Jellyfin server. The token is stored in the macOS Keychain.
- Browse albums, artists, and playlists, with artwork and search.
- Play, pause, next, previous, seek, and volume. Double-click a track to play from there.
- Shuffle and repeat (off, all, one). Both persist across launches.
- Up Next queue panel (Cmd+Shift+U): Play Next and Add to Queue from tracks, albums, and playlists; drag to reorder, Delete to remove, double-click to jump, Clear to drop the rest.
- Track format in the track list and the player bar: codec, bit depth, sample rate, and bit rate.
- Now Playing integration: Control Center, media keys, and the playback position scrubber.
- Playback reports to the server, so play counts and history update.
- Sparkle updates from the GitHub release feed, once a signing key is configured.

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

## Releases

Updates come from Sparkle. The app checks `SUFeedURL` from `project.yml`, which points at the latest GitHub release. Until `SUPublicEDKey` is set, the updater stays off and "Check for Updates…" is disabled.

1. Install the Sparkle tools once: `brew install --cask sparkle`.
2. Run `generate_keys` once. It stores the private key in your login Keychain and prints the public key. Put the public key in `SUPublicEDKey` in `project.yml`, then run `make gen`.
3. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
4. Run `make release`. It archives, exports, builds `build/Diapason.dmg`, and writes `build/appcast.xml`. A Developer ID certificate is needed for `make dmg`; use `make dmg-unsigned` for a personal build.
5. Create a GitHub release and upload the DMG and `appcast.xml` as assets.

## Layout

```
Sources/Diapason/
  Jellyfin/   REST client, credentials, Keychain, Library (server state)
  Player/     PlayQueue, Player (AVPlayer), NowPlaying (MediaPlayer bridge), RepeatMode
  Updates/    UpdaterController (Sparkle)
  Models/     Track and MediaInfo, MusicCollection, Artist, SidebarItem
  Views/      RootView, SidebarView, AlbumsView, ArtistsView, TrackListView, QueueView, PlayerBar, SignInView, SettingsView
Tests/DiapasonTests/     unit tests (Swift Testing, ViewInspector)
Tests/DiapasonUITests/   XCUITest end-to-end flow
```
