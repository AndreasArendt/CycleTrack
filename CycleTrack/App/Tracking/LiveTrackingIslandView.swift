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
    private enum IslandPage {
        case myTracking
        case watchingOthers
    }

    @State private var isExpanded: Bool = false
    @State private var isSharingPresented: Bool = false
    @State private var selectedPage: IslandPage = .myTracking
    @StateObject private var trackingManager = TrackingManager()
    @State private var stopSliderOffset: CGFloat = 0
    
    @ObservedObject var locationManager: LocationManager
    let watchedActivities: [WatchedActivity]
    let watchingStatusMessage: String?
    let onAddActivity: () -> Void
    let onRemoveWatchedActivity: (WatchedActivity) -> Void
    
    private let actions = [
        TrackingAction(title: "Share", systemImage: "square.and.arrow.up"),
        TrackingAction(title: "Settings", systemImage: "gearshape"),
    ]

    init(
        locationManager: LocationManager,
        watchedActivities: [WatchedActivity] = [],
        watchingStatusMessage: String? = nil,
        onAddActivity: @escaping () -> Void = {},
        onRemoveWatchedActivity: @escaping (WatchedActivity) -> Void = { _ in }
    ) {
        self.locationManager = locationManager
        self.watchedActivities = watchedActivities
        self.watchingStatusMessage = watchingStatusMessage
        self.onAddActivity = onAddActivity
        self.onRemoveWatchedActivity = onRemoveWatchedActivity
    }

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 4)

            pageSwitcher

            HStack(spacing: 12) {
                Image(systemName: selectedPage == .myTracking ? "location.fill" : "figure.outdoor.cycle")
                    .foregroundStyle(selectedPage == .myTracking ? .green : .blue)
                    .frame(width: 32, height: 32)
                    .background((selectedPage == .myTracking ? Color.green : Color.blue).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPage == .myTracking ? "Live Tracking" : "Tracking Riders")
                        .font(.headline)

                    Text(selectedPage == .myTracking ? trackingStatusText : watchingStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedPage == .myTracking {
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
                } else {
                    Button {
                        onAddActivity()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                }
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
        .onAppear {
            trackingManager.observeWatchers(activityId: locationManager.currentActivityId)
        }
        .onChange(of: locationManager.currentActivityId) { _, activityId in
            trackingManager.observeWatchers(activityId: activityId)
        }
        .onReceive(trackingManager.$watchers) { watchers in
            locationManager.setActiveWatcherCount(watchers.filter(\.isActive).count)
        }
    }

    private var expandedContent: some View {
        Group {
            if selectedPage == .myTracking {
                myTrackingContent
            } else {
                watchingOthersContent
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }

                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        if value.translation.width < -40 {
                            selectedPage = .watchingOthers
                        } else if value.translation.width > 40 {
                            selectedPage = .myTracking
                        }
                    }
                }
        )
    }

    private var myTrackingContent: some View {
        VStack(spacing: 16) {
            WatcherSectionView(watchers: trackingManager.watchers) { watcher in
                trackingManager.removeWatcher(watcher)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: actions.count), spacing: 10) {
                ForEach(actions) { action in
                    CycleTrackActionButton(action: action) {
                        handleAction(action)
                    }
                }
            }

            if isSharingPresented {
                SharingView(activityId: locationManager.currentActivityId)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack {
                Spacer()

                Text(locationManager.hasGPSFix ? "" : "Waiting for Position")
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

    private var watchingOthersContent: some View {
        VStack(spacing: 16) {
            WatchingOthersSectionView(
                watchedActivities: watchedActivities,
                statusMessage: watchingStatusMessage,
                onAddActivity: onAddActivity,
                onRemoveActivity: onRemoveWatchedActivity
            )
        }
    }

    private var pageSwitcher: some View {
        HStack(spacing: 4) {
            pageButton(page: .myTracking, systemImage: "location.fill")
            pageButton(page: .watchingOthers, systemImage: "figure.outdoor.cycle")
        }
        .padding(3)
        .background(.thinMaterial, in: Capsule())
    }

    private func pageButton(page: IslandPage, systemImage: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                selectedPage = page
                isExpanded = true
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selectedPage == page ? .white : .secondary)
                .frame(width: 42, height: 34)
                .background(
                    selectedPage == page ? Color.accentColor : .clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var trackingStatusText: String {
        if locationManager.isSending {
            return "Sharing for \(locationManager.trackingDurationText)"
        }

        if locationManager.isPaused {
            return "Paused at \(locationManager.trackingDurationText)"
        }

        return "Start sharing"
    }

    private var watchingStatusText: String {
        let count = watchedActivities.count

        if count == 1 {
            return "Watching 1 rider"
        }

        return "Watching \(count) riders"
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

private struct WatchingOthersSectionView: View {
    let watchedActivities: [WatchedActivity]
    let statusMessage: String?
    let onAddActivity: () -> Void
    let onRemoveActivity: (WatchedActivity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Riders", systemImage: "map")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if watchedActivities.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No riders yet")
                            .font(.subheadline.weight(.semibold))

                        Text("Add an invitation token to start tracking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(watchedActivities) { activity in
                        SwipeToRemoveWatchedActivityRow(activity: activity) {
                            onRemoveActivity(activity)
                        }
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct SwipeToRemoveWatchedActivityRow: View {
    let activity: WatchedActivity
    let onRemove: () -> Void

    @State private var offset: CGFloat = 0

    private let removeWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    onRemove()
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: removeWidth, height: 42)
                    .background(.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            watchedActivityRow
                .padding(.horizontal, 10)
                .frame(height: 42)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            offset = max(-removeWidth, min(0, value.translation.width))
                        }
                        .onEnded { value in
                            let shouldReveal = value.translation.width < -34 || value.predictedEndTranslation.width < -70

                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                offset = shouldReveal ? -removeWidth : 0
                            }
                        }
                )
        }
        .clipped()
    }

    private var watchedActivityRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.outdoor.cycle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(activity.status == "live" ? .green : .secondary)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.ownerUid ?? activity.id)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(activity.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(activity.status.capitalized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(activity.status == "live" ? .green : .secondary)
        }
    }
}

#Preview {
    LiveTrackingIslandView(locationManager: LocationManager())
}
