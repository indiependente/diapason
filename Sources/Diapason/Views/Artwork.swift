import AppKit
import SwiftUI

/// Album art with a placeholder while it loads or when there is none.
struct Artwork: View {
    let url: URL?
    var cornerRadius: CGFloat = 6
    @State private var loaded: NSImage?

    var body: some View {
        ZStack {
            if let image = loaded ?? ImageCache.shared.cached(url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            loaded = await ImageCache.shared.image(for: url)
        }
    }
}

/// Keeps decoded artwork in memory and shares in-flight downloads, so a list of rows from the same
/// album costs one request and re-renders instantly.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<Data?, Never>] = [:]

    func cached(_ url: URL?) -> NSImage? {
        url.flatMap { cache.object(forKey: $0 as NSURL) }
    }

    func image(for url: URL?) async -> NSImage? {
        guard let url else {
            return nil
        }
        if let image = cached(url) {
            return image
        }
        let task = inFlight[url] ?? Task { try? await URLSession.shared.data(from: url).0 }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil
        guard let data, let image = NSImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: url as NSURL)

        return image
    }
}
