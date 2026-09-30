@testable import Diapason
import Testing

@Suite("Navigation")
@MainActor
struct NavigationTests {
    @Test("show(album:) switches to Albums, clears the search, and pushes the album")
    func showAlbum() {
        let navigation = Navigation()
        navigation.selection = .favorites
        navigation.query = "let it"
        navigation.show(album: MusicCollection(id: "a1", name: "Currents", kind: .album))
        #expect(navigation.selection == .albums)
        #expect(navigation.query.isEmpty)
        #expect(navigation.albumsPath.count == 1)
    }

    @Test("show(artist:) switches to Artists and pushes the artist")
    func showArtist() {
        let navigation = Navigation()
        navigation.show(artist: Artist(id: "ar1", name: "Tame Impala"))
        #expect(navigation.selection == .artists)
        #expect(navigation.artistsPath.count == 1)
    }
}
