import SwiftUI

struct TrackingControlView: View {
    @StateObject private var sender = LocationSender()
    @StateObject private var auth = AuthenticationService()
    @State private var isSigningIn = false
    @State private var isWritingDummyEntry = false
    @State private var dummyWriteMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(auth.isSignedIn ? "Signed in anonymously" : "Signed out")
                    .font(.headline)

                if let userId = auth.userId {
                    Text(userId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if auth.isSignedIn {
                    Button {
                        signOut()
                    } label: {
                        Label("Sign out", systemImage: "person.crop.circle.badge.xmark")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        signIn()
                    } label: {
                        if isSigningIn {
                            ProgressView()
                        } else {
                            Label("Sign in anonymously", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSigningIn)
                }

                if let statusMessage = auth.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Divider()

            Text(sender.isSending ? "Sending location every 10s" : "Not sending")
                .font(.headline)

            if let msg = sender.statusMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 20) {
                Button(sender.isSending ? "Stop" : "Start") {
                    if sender.isSending { sender.stop() } else { sender.start() }
                }
                .buttonStyle(.borderedProminent)

                Toggle("Background updates", isOn: $sender.allowsBackgroundUpdates)
                    .toggleStyle(.switch)
            }

            Divider()

            Button {
                writeDummyEntry()
            } label: {
                if isWritingDummyEntry {
                    ProgressView()
                } else {
                    Label("Write dummy entry", systemImage: "square.and.pencil")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isWritingDummyEntry || !auth.isSignedIn)

            if let dummyWriteMessage {
                Text(dummyWriteMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            // reflect current authorization state
            _ = sender.authorizationStatus
        }
    }

    private func signIn() {
        isSigningIn = true
        auth.statusMessage = "Signing in..."

        Task {
            do {
                _ = try await auth.signInAnonymously()
            } catch {
                auth.statusMessage = "Sign in failed: \(error.localizedDescription)"
            }

            isSigningIn = false
        }
    }

    private func signOut() {
        do {
            try auth.signOut()
            dummyWriteMessage = nil
        } catch {
            auth.statusMessage = error.localizedDescription
        }
    }

    private func writeDummyEntry() {
        isWritingDummyEntry = true
        dummyWriteMessage = "Writing dummy entry..."

        Task {
            do {
                let documentId = try await FirebaseService.shared.writeDummyTrackingEntry()
                dummyWriteMessage = "Wrote trackingEntries/\(documentId)"
            } catch {
                dummyWriteMessage = "Dummy write failed: \(error.localizedDescription)"
            }

            isWritingDummyEntry = false
        }
    }
}

#Preview {
    TrackingControlView()
}
