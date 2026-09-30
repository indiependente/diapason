import SwiftUI

/// Where the window is: the sidebar selection, the search text, and the pushed album or artist pages.
/// Lives above the views so a song's context menu can jump anywhere.
@Observable
@MainActor
final class Navigation {
    var selection: SidebarItem? = .albums
    var query = ""
    var albumsPath = NavigationPath()
    var artistsPath = NavigationPath()

    func show(album: MusicCollection) {
        query = ""
        selection = .albums
        albumsPath = NavigationPath([album])
    }

    func show(artist: Artist) {
        query = ""
        selection = .artists
        artistsPath = NavigationPath([artist])
    }
}
