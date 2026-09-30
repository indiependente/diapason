import SwiftUI

struct SidebarView: View {
    @Environment(Library.self) private var library
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("Albums", systemImage: "square.stack")
                    .tag(SidebarItem.albums)
                Label("Artists", systemImage: "music.microphone")
                    .tag(SidebarItem.artists)
            }
            Section("Playlists") {
                ForEach(library.playlists) { playlist in
                    Label(playlist.name, systemImage: "music.note.list")
                        .tag(SidebarItem.playlist(playlist))
                }
            }
        }
        .navigationTitle("Diapason")
        .overlay(alignment: .bottom) {
            if let message = library.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
    }
}
