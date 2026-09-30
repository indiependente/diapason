enum SidebarItem: Hashable {
    case albums
    case artists
    case favorites
    case playlist(MusicCollection)
}
