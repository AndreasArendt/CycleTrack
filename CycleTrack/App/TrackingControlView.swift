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
//                HStack {
//                    Spacer()
//                    menuButton
//                    locationButton
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, 12)

                Spacer()

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
        
    struct LiveTrackingIslandView: View {
        @State private var isExpanded: Bool = false
        @State private var trackingManager = TrackingManager()
        @State private var stopSliderOffset: CGFloat = 0
        
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

                        Text(trackingStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        if locationManager.isSending {
                            pauseTracking()
                        } else if locationManager.isPaused {
                            resumeTracking()
                        } else {
                            startTracking()
                        }
                    } label: {
                        Image(systemName: primaryControlImage)
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(primaryControlTint)
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
                watcherSection
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
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
                            .padding(.vertical, 4)
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

                if locationManager.isSending || locationManager.isPaused {
                    slideToStopControl
                }
            }
        }

        private var trackingStatusText: String {
            if locationManager.isSending {
                return "Sharing for \(locationManager.trackingDurationText)"
            }

            if locationManager.isPaused {
                return "Paused at \(locationManager.trackingDurationText)"
            }

            return "Ready to share"
        }

        private var primaryControlImage: String {
            if locationManager.isSending {
                return "pause.fill"
            }

            return "play.fill"
        }

        private var primaryControlTint: Color {
            if locationManager.isSending {
                return .orange
            }

            return .green
        }

        private var slideToStopControl: some View {
            GeometryReader { proxy in
                let knobSize: CGFloat = 44
                let maxOffset = max(0, proxy.size.width - knobSize - 8)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.red.opacity(0.12))

                    Text("Slide to stop sharing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)

                    Circle()
                        .fill(.red)
                        .frame(width: knobSize, height: knobSize)
                        .overlay {
                            Image(systemName: "stop.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: stopSliderOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    stopSliderOffset = min(max(0, value.translation.width), maxOffset)
                                }
                                .onEnded { _ in
                                    if stopSliderOffset > maxOffset * 0.72 {
                                        stopTracking()
                                    }

                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                        stopSliderOffset = 0
                                    }
                                }
                        )
                }
            }
            .frame(height: 52)
        }

        private var watcherSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Watchers", systemImage: "person.and.person")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(activeWatcherCount) active")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if trackingManager.watchers.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(.thinMaterial, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No watchers yet")
                                .font(.subheadline.weight(.semibold))

                            Text("Share your live link to invite people.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ForEach(trackingManager.watchers.prefix(3)) { watcher in
                            watcherRow(watcher)
                        }
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }

        private var activeWatcherCount: Int {
            trackingManager.watchers.filter(\.isActive).count
        }

        private func watcherRow(_ watcher: Watcher) -> some View {
            HStack(spacing: 10) {
                Group {
                    if let image = watcher.image {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())
                .clipShape(Circle())

                Text(watcher.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Circle()
                    .fill(watcher.isActive ? .green : .secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        
        private func startTracking() {
            locationManager.startSending()
        }

        private func pauseTracking() {
            locationManager.pauseSending()
        }

        private func resumeTracking() {
            locationManager.resumeSending()
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
