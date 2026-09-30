import SwiftUI

struct UpdateBubble: View {
    let updater: UpdaterController

    var body: some View {
        if updater.updateAvailable {
            Button { updater.checkForUpdates() } label: {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.tint, in: .capsule)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
        }
    }
}
