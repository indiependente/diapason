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

- Sign in to a Jellyfin server. The session token is stored in `~/Library/Application Support/Diapason/credentials.json` with owner-only permissions. The Keychain is not used because an ad-hoc signed development build gets a new code signature on every rebuild, and the Keychain then asks for permission at every launch.
- Browse albums, artists, songs, and playlists, with artwork. Songs lists the whole library, so Play or Shuffle there plays everything.
- Large artwork: hover the cover in the player bar and click the chevron to show it as a big square at the bottom of the sidebar. The chevron on the big cover makes it small again.
- Favorites: heart a song in any list or in the player bar, and browse them under Favorites in the sidebar.
- Go to Album and Go to Artist from any song's context menu, from the player bar, and from the Controls menu.
- Search the whole library from the sidebar: songs come from the server, artists and albums from the loaded lists.
- Play, pause, next, previous, seek, and volume. Double-click a track to play from there.
- Shuffle and repeat (off, all, one). Both persist across launches.
- Lyrics panel (Cmd+Shift+L, the microphone button): synced lyrics follow the song, and a click on a line seeks to it.
- Up Next queue panel (Cmd+Shift+U): Play Next and Add to Queue from tracks, albums, and playlists; drag to reorder, Delete to remove, double-click to jump, Clear to drop the rest.
- Track format in the track list and the player bar: codec, bit depth, sample rate, and bit rate.
- Now Playing integration: Control Center, media keys, and the playback position scrubber.
- Playback reports to the server, so play counts and history update.
- Sparkle updates from the GitHub release feed, once a signing key is configured.

FLAC, MP3, AAC, ALAC, WAV, and AIFF play directly. The server transcodes other formats to AAC.

## End-to-end test

`make test-e2e` drives the real app against a Jellyfin server: sign-in, playback and the stop report on quit, artists, search, the side panels, favorites, and the large artwork. It needs a reachable server:

```sh
DIAPASON_TEST_SERVER=http://192.168.0.14:8096 \
DIAPASON_TEST_USER=jellyfin \
DIAPASON_TEST_PASSWORD="$(cat ~/jellyfin_pass.txt)" \
make test-e2e
```

Each feature has its own test. Add `ONLY=PlaybackUITests/testSearch` to run one of them. Without these variables the tests are skipped. The test launches the app with `-DiapasonFreshSession`, which keeps the session in memory, so your stored sign-in is not touched.

## Releases

Push a version tag. The Release workflow runs the unit tests, builds `Diapason-<version>.dmg` with that version and the run number as the build number, and publishes a GitHub release with the DMG attached.

```sh
git tag v0.2.0
git push origin v0.2.0
```

Updates come from Sparkle, which reads `appcast.xml` from the latest GitHub release. Set this up once:

1. Install the Sparkle tools: `brew install --cask sparkle`.
2. Run `generate_keys`. It stores the private key in your login Keychain and prints the public key.
3. Put the public key in `SUPublicEDKey` in `project.yml`, then commit it. Until this key is set, the updater stays off and "Check for Updates…" is disabled.
4. Run `generate_keys -x sparkle-key.txt` and save the file content as the `SPARKLE_ED_PRIVATE_KEY` repository secret. Then delete the file. Without this secret, releases have no `appcast.xml`.

The DMG is ad-hoc signed, not notarized, because the project has no Developer ID certificate. The release notes tell users how to clear the quarantine flag. `make dmg` builds a Developer ID signed DMG locally once a certificate and a team are set up.

## Layout

```
Sources/Diapason/
  Jellyfin/   REST client, credentials, SecretStore, Library (server state)
  Player/     PlayQueue, Player (AVPlayer), NowPlaying (MediaPlayer bridge), RepeatMode
  Updates/    UpdaterController (Sparkle)
  Models/     Track and MediaInfo, MusicCollection, Artist, LyricLine, SidebarItem, Navigation
  Views/      RootView, SidebarView, AlbumsView, ArtistsView, SearchView, TrackListView, QueueView, LyricsView, NowPlayingArtwork, PlayerBar, SignInView, SettingsView
Tests/DiapasonTests/     unit tests (Swift Testing, ViewInspector)
Tests/DiapasonUITests/   XCUITest end-to-end flow
```
