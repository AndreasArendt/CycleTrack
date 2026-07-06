import SwiftUI
import MapKit

struct TrackingControlView: View {
    @StateObject private var auth = AuthenticationService()
    @State private var isSigningIn = false
    @State private var isWritingDummyEntry = false
    @State private var dummyWriteMessage: String?
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @StateObject private var locationManager = LocationManager()
    
    @Namespace private var mapScope
    
    init(
        auth: AuthenticationService = AuthenticationService(),
        locationManager: LocationManager = LocationManager()
    ) {
        _auth = StateObject(wrappedValue: auth)
        _locationManager = StateObject(wrappedValue: locationManager)
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
                HStack {
                    Spacer()

                    //menuButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                locationButton

                LiveTrackingIslandView(locationManager: locationManager)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            locationManager.requestLocationAuthorization()
        }
    }

    private var locationButton: some View
    {
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
    }
    
    private var menuButton: some View {
        Menu {
            Label(auth.providerName, systemImage: "person.crop.circle")

            if let userId = auth.userId {
                Label("Rider \(userId.prefix(8))", systemImage: "number")
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
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
    }
    
    struct LiveTrackingIslandView: View {
        @State private var isExpanded: Bool = false

        @ObservedObject var locationManager: LocationManager
        
        private let actions = [
            TrackingAction(title: "Share", systemImage: "square.and.arrow.up"),
            TrackingAction(title: "Watchers", systemImage: "person.and.person"),
            TrackingAction(title: "History", systemImage: "clock"),
            TrackingAction(title: "Settings", systemImage: "gearshape"),
        ]
        
        var body: some View {
            VStack(spacing: 14) {
                Capsule()
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 38, height: 5)
                    .padding(.top, 4)

                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(.green.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Tracking")
                            .font(.headline)

                        Text(locationManager.isSending ? "Sharing location" : "Ready to share")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        if locationManager.isSending {
                            stopTracking()
                        } else {
                            startTracking()
                        }
                    } label: {
                        Image(systemName: locationManager.isSending ? "stop.fill" : "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(locationManager.isSending ? .red : .green)
                }

                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, isExpanded ? 18 : 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 28 : 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isExpanded ? 28 : 26, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let shouldExpand = value.translation.height < -40 || value.predictedEndTranslation.height < -90
                        let shouldCollapse = value.translation.height > 40 || value.predictedEndTranslation.height > 90

                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            if shouldExpand {
                                isExpanded = true
                            } else if shouldCollapse {
                                isExpanded = false
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isExpanded)
        }

        private var expandedContent: some View {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    RideMetricView(title: "Duration", value: "00:00")
                    RideMetricView(title: "Speed", value: "0.0")
                    RideMetricView(title: "Watching", value: "0")
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: actions.count), spacing: 10) {
                    ForEach(actions) { action in
                        Button {
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.systemImage)
                                    .font(.headline)
                                    .frame(width: 34, height: 34)
                                    .background(.thinMaterial, in: Circle())

                                Text(action.title)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Label("Last update", systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(locationManager.hasGPSFix ? "Tracking" : "Waiting for Position")
                        .foregroundStyle(locationManager.hasGPSFix ? .green : .secondary)
                }
                .font(.caption)
            }
        }
        
        private func startTracking() {
            locationManager.startSending()
        }
        
        private func stopTracking() {
            locationManager.stopSending()
        }

        private struct TrackingAction: Identifiable {
            let title: String
            let systemImage: String

            var id: String { title }
        }
    }

    private struct RideMetricView: View {
        let title: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        auth: AuthenticationService(previewUserId: "preview-user"),
        locationManager: LocationManager(preview: true)
    )
}
