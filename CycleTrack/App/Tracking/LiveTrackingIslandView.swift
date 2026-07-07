import SwiftUI

struct TrackingAction: Identifiable {
    let title: String
    let systemImage: String?
    let resourceImage: String?
    
    var id: String { title }
    
    init(title: String, systemImage: String?) {
        self.title = title
        self.systemImage = systemImage
        self.resourceImage = nil
    }
    
    init(title:String, resourceImage: String?) {
        self.title = title
        self.resourceImage = resourceImage
        self.systemImage = nil
    }
}

struct LiveTrackingIslandView: View {
    @State private var isExpanded: Bool = false
    @State private var isSharingPresented: Bool = false
    @State private var trackingManager = TrackingManager()
    @State private var stopSliderOffset: CGFloat = 0
    
    @ObservedObject var locationManager: LocationManager
    
    private let actions = [
        TrackingAction(title: "Share", systemImage: "square.and.arrow.up"),
        TrackingAction(title: "Add Rider", systemImage: "figure.outdoor.cycle"),
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
            WatcherSectionView(watchers: trackingManager.watchers)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: actions.count), spacing: 10) {
                ForEach(actions) { action in
                    CycleTrackActionButton(action: action) {
                        handleAction(action)
                    }
                }
            }

            if isSharingPresented {
                SharingView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                SlideToStopControl(stopSliderOffset: stopSliderOffset) {
                    stopTracking()
                }
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

    private func startTracking() {
        locationManager.startSending()
    }

    private func pauseTracking() {
        locationManager.pauseSending()
    }

    private func resumeTracking() {
        locationManager.resumeSending()
    }

    private func handleAction(_ action: TrackingAction) {
        guard action.title == "Share" else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isExpanded = true
            isSharingPresented.toggle()
        }
    }
    
    private func stopTracking() {
        locationManager.stopSending()
    }

}

#Preview {
    LiveTrackingIslandView(locationManager: LocationManager())
}
