import SwiftUI

struct SettingsView: View {
    @Environment(Library.self) private var library
    /// Sparkle reads this key from UserDefaults, so the toggle drives it directly.
    @AppStorage("SUEnableAutomaticChecks") private var automaticUpdates = true

    var body: some View {
        Form {
            Section("Account") {
                if let credentials = library.credentials {
                    LabeledContent("Server", value: credentials.server.absoluteString)
                    LabeledContent("User", value: credentials.username)
                    Button("Sign Out", role: .destructive) { library.signOut() }
                } else {
                    Text("Not signed in.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $automaticUpdates)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
