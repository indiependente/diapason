import AppKit
import SwiftUI

/// Artwork of the playing song, in one of two sizes. A click on the artwork switches to the other size.
/// A chevron shows on hover as a hint. The chevron is decorative: the artwork itself is the button.
struct NowPlayingArtwork: View {
    let image: NSImage?
    let isLarge: Bool
    let toggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: isLarge ? .topTrailing : .center) {
            artwork
            Image(systemName: isLarge ? "chevron.down" : "chevron.up")
                .font(isLarge ? .callout.weight(.semibold) : .caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: isLarge ? 26 : 20, height: isLarge ? 26 : 20)
                .background(.black.opacity(0.45), in: Circle())
                .padding(isLarge ? 8 : 0)
                .opacity(isHovering ? 1 : 0)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .help(isLarge ? "Show Smaller Artwork" : "Show Larger Artwork")
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isLarge ? "Show Smaller Artwork" : "Show Larger Artwork")
        .accessibilityIdentifier(isLarge ? "artworkCollapseButton" : "artworkExpandButton")
        .accessibilityAction { toggle() }
    }

    @ViewBuilder
    private var artwork: some View {
        let radius: CGFloat = isLarge ? 8 : 4
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: radius))
                .shadow(radius: isLarge ? 3 : 0, y: isLarge ? 1 : 0)
        } else {
            Artwork(url: nil, cornerRadius: radius)
        }
    }
}
