import SwiftUI

struct SignInView: View {
    @Environment(Library.self) private var library
    @AppStorage("serverURL") private var server = ""
    @AppStorage("username") private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Diapason")
                .font(.largeTitle.bold())
            Text("Sign in to your Jellyfin server.")
                .foregroundStyle(.secondary)
            Form {
                TextField("Server", text: $server, prompt: Text("http://192.168.0.14:8096"))
                    .textContentType(.URL)
                    .accessibilityIdentifier("serverField")
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .accessibilityIdentifier("usernameField")
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityIdentifier("passwordField")
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 420)
            .onSubmit(signIn)
            if let message = library.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Sign In", action: signIn)
                .accessibilityIdentifier("signInButton")
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(library.isLoading || server.isEmpty || username.isEmpty)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func signIn() {
        Task { await library.signIn(server: server, username: username, password: password) }
    }
}
