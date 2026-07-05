import SwiftUI
import MapKit

struct TrackingControlView: View {
    @StateObject private var sender = LocationSender()
    @StateObject private var auth = AuthenticationService()
    @State private var isSigningIn = false
    @State private var isWritingDummyEntry = false
    @State private var dummyWriteMessage: String?
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Namespace private var mapScope
    
    init(
        sender: LocationSender = LocationSender(),
        auth: AuthenticationService = AuthenticationService()
    ) {
        _sender = StateObject(wrappedValue: sender)
        _auth = StateObject(wrappedValue: auth)
    }
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition, scope: mapScope) {
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()
            .mapScope(mapScope)

            VStack(spacing: 0) {
                headerView

                Spacer()

                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            cameraPosition = .userLocation(
                                followsHeading: false,
                                fallback: .automatic
                            )}
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(.blue, in: Circle())
                            .shadow(radius: 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                LiveTrackingIslandView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    private var headerView: some View {
        ZStack {
            Text("CycleTrack")
                .font(.headline.weight(.semibold))

            HStack {
                Text(auth.providerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())

                Spacer()

                menuButton
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 54)
        .background(.ultraThinMaterial)
        .overlay {
            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }

    private var menuButton: some View {
        Menu {
            if let userId = auth.userId {
                Label("Rider \(userId.prefix(8))", systemImage: "person.crop.circle")
            }

            Button {
                writeDummyEntry()
            } label: {
                Label("Write Test Entry", systemImage: "square.and.pencil")
            }
            .disabled(isWritingDummyEntry)

            Divider()

            Button(role: .destructive) {
                signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
    }
    
    struct LiveTrackingIslandView: View {
        @State private var isTracking: Bool = false
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Tracking")
                        .font(.headline)

                    Text("Sharing location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if isTracking {
                        stopTracking()
                    } else {
                        startTracking()
                    }

                    isTracking.toggle()
                } label: {
                    Image(systemName: isTracking ? "stop.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isTracking ? .red : .green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 12)
        }
        
        private func startTracking() {
            
        }
        
        private func stopTracking() {
            
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
    TrackingControlView(
        sender: LocationSender(preview: true),
        auth: AuthenticationService(previewUserId: "preview-user")
    )
}
