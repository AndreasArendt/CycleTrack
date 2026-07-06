import Combine
import CoreLocation
import Foundation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let locationRepository: LocationRepository
    private let isPreview: Bool
    private var sendTimer: Timer?
    private var durationTimer: Timer?
    private var trackingStartedAt: Date?
    private var accumulatedTrackingSeconds: TimeInterval = 0
    private var shouldStartSendingAfterAuthorization = false

    @Published var currentLocation: CLLocation?
    @Published var hasGPSFix = false
    @Published var horizontalAccuracy: CLLocationAccuracy?
    @Published var isSending = false
    @Published var isPaused = false
    @Published var elapsedTrackingSeconds: TimeInterval = 0
    @Published var statusMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var allowsBackgroundUpdates = false {
        didSet {
            updateBackgroundLocationUpdates()

            if allowsBackgroundUpdates && authorizationStatus != .authorizedAlways {
                statusMessage = "Background updates require 'Always' location access. Requesting..."
                requestAlwaysAuthorizationIfNeeded()
            }
        }
    }

    var currentSpeedText: String {
        guard let speed = currentLocation?.speed, speed >= 0 else {
            return "--"
        }

        return String(format: "%.1f", speed * 3.6)
    }

    var trackingDurationText: String {
        Self.formatDuration(elapsedTrackingSeconds)
    }

    init(preview: Bool = false, locationRepository: LocationRepository? = nil) {
        isPreview = preview
        self.locationRepository = locationRepository ?? LocationRepository(preview: preview)

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = preview ? .authorizedWhenInUse : manager.authorizationStatus
    }

    deinit {
        sendTimer?.invalidate()
        durationTimer?.invalidate()
    }

    func requestLocationAuthorization() {
        guard !isPreview else { return }

        switch authorizationStatus {
        case .notDetermined:
            requestWhenInUseAuthorizationOnMain()
            statusMessage = "Requesting location permission..."
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    func startSending() {
        if isPreview {
            isSending = true
            isPaused = false
            startDurationTimer()
            statusMessage = "Preview: sending every 10s."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            shouldStartSendingAfterAuthorization = true
            requestWhenInUseAuthorizationOnMain()
            statusMessage = "Requesting location permission..."
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            beginSending()
            if allowsBackgroundUpdates {
                requestAlwaysAuthorizationIfNeeded()
            }
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    func stopSending() {
        shouldStartSendingAfterAuthorization = false
        isSending = false
        isPaused = false
        sendTimer?.invalidate()
        sendTimer = nil
        resetDurationTimer()

        if !isPreview {
            manager.stopUpdatingLocation()
        }

        statusMessage = "Stopped sending."
    }

    func pauseSending() {
        guard isSending, !isPaused else { return }

        isPaused = true
        isSending = false
        sendTimer?.invalidate()
        sendTimer = nil
        pauseDurationTimer()

        if !isPreview {
            manager.stopUpdatingLocation()
        }

        statusMessage = "Paused."
    }

    func resumeSending() {
        guard isPaused else { return }

        if isPreview {
            isPaused = false
            isSending = true
            startDurationTimer()
            statusMessage = "Preview: sending every 10s."
            return
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isPaused = false
            beginSending()
        case .notDetermined:
            shouldStartSendingAfterAuthorization = true
            requestWhenInUseAuthorizationOnMain()
            statusMessage = "Requesting location permission..."
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    private func beginSending() {
        guard !isSending else { return }

        if allowsBackgroundUpdates && authorizationStatus != .authorizedAlways {
            statusMessage = "Background updates requested but not authorized for 'Always'. Requesting..."
            requestAlwaysAuthorizationIfNeeded()
        }

        manager.startUpdatingLocation()

        if CLLocationManager.locationServicesEnabled(),
           manager.responds(to: #selector(CLLocationManager.requestLocation)) {
            manager.requestLocation()
        }

        isSending = true
        isPaused = false
        startDurationTimer()
        statusMessage = "Started sending every 10s."
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }

        if let sendTimer {
            RunLoop.main.add(sendTimer, forMode: .common)
        }
    }

    private func sendCurrentLocation() {
        guard let currentLocation else {
            statusMessage = "No location available yet."
            return
        }

        sendLocation(currentLocation)
    }

    private func sendLocation(_ location: CLLocation) {
        locationRepository.saveCurrentRiderLocation(location) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.statusMessage = "Failed to send: \(error.localizedDescription)"
                } else {
                    self?.statusMessage = "Sent at \(Date().formatted(date: .omitted, time: .standard))"
                }
            }
        }
    }

    private func updateLocationState(with location: CLLocation) {
        currentLocation = location
        horizontalAccuracy = location.horizontalAccuracy
        hasGPSFix = location.horizontalAccuracy > 0 && location.horizontalAccuracy < 20
    }

    private func startDurationTimer() {
        guard trackingStartedAt == nil else { return }

        trackingStartedAt = Date()
        elapsedTrackingSeconds = accumulatedTrackingSeconds
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsedTrackingSeconds()
        }

        if let durationTimer {
            RunLoop.main.add(durationTimer, forMode: .common)
        }
    }

    private func pauseDurationTimer() {
        updateElapsedTrackingSeconds()
        durationTimer?.invalidate()
        durationTimer = nil
        accumulatedTrackingSeconds = elapsedTrackingSeconds
        trackingStartedAt = nil
    }

    private func resetDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        trackingStartedAt = nil
        accumulatedTrackingSeconds = 0
        elapsedTrackingSeconds = 0
    }

    private func updateElapsedTrackingSeconds() {
        guard let trackingStartedAt else { return }

        elapsedTrackingSeconds = accumulatedTrackingSeconds + Date().timeIntervalSince(trackingStartedAt)
    }

    private func updateBackgroundLocationUpdates() {
        let enable = allowsBackgroundUpdates && authorizationStatus == .authorizedAlways
        manager.allowsBackgroundLocationUpdates = enable

        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = enable
        }
    }

    private func requestWhenInUseAuthorizationOnMain() {
        if Thread.isMainThread {
            manager.requestWhenInUseAuthorization()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.manager.requestWhenInUseAuthorization()
            }
        }
    }

    private func requestAlwaysAuthorizationIfNeeded() {
        guard authorizationStatus == .authorizedWhenInUse else { return }

        if Thread.isMainThread {
            manager.requestAlwaysAuthorization()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.manager.requestAlwaysAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateBackgroundLocationUpdates()

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if shouldStartSendingAfterAuthorization {
                shouldStartSendingAfterAuthorization = false
                beginSending()
            } else if isSending {
                manager.startUpdatingLocation()
            }

            if allowsBackgroundUpdates && authorizationStatus == .authorizedWhenInUse {
                statusMessage = "Background updates require 'Always' access. Requesting..."
                requestAlwaysAuthorizationIfNeeded()
            }
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
            stopSending()
        case .notDetermined:
            statusMessage = "Requesting location permission..."
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        updateLocationState(with: latest)

        if isSending {
            sendLocation(latest)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Location error: \(error.localizedDescription)"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
