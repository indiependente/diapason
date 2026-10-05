enum SidebarItem: Hashable {
    case albums
    case artists
    case songs
    case favorites
    case playlist(MusicCollection)
}
