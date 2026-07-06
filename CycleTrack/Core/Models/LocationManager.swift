import Combine
import CoreLocation
import Foundation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let locationRepository: LocationRepository
    private let isPreview: Bool
    private var sendTimer: Timer?
    private var shouldStartSendingAfterAuthorization = false

    @Published var currentLocation: CLLocation?
    @Published var hasGPSFix = false
    @Published var horizontalAccuracy: CLLocationAccuracy?
    @Published var isSending = false
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
        sendTimer?.invalidate()
        sendTimer = nil

        if !isPreview {
            manager.stopUpdatingLocation()
        }

        statusMessage = "Stopped sending."
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
}
