import SwiftUI

struct SettingsView: View {
    @Environment(Library.self) private var library

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
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
