import Foundation
import CoreLocation
import UIKit
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Firestore compatibility shim
#if canImport(FirebaseFirestore)
private typealias DBFieldValue = FieldValue
#else
private enum DBFieldValue {
    static func serverTimestamp() -> Any { Date() }
}
#endif

// Provide a DB client abstraction that compiles without Firebase
private protocol DBClient {
    func setLocation(riderId: String, latitude: Double, longitude: Double, timestamp: Any, completion: @escaping (Error?) -> Void)
}

#if canImport(FirebaseFirestore)
private struct FirestoreClient: DBClient {
    private let db = Firestore.firestore()
    func setLocation(riderId: String, latitude: Double, longitude: Double, timestamp: Any, completion: @escaping (Error?) -> Void) {
        let data: [String: Any] = [
            "riderId": riderId,
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": timestamp
        ]
        db.collection("riderLocations").document(riderId).setData(data, merge: true) { error in
            completion(error)
        }
    }
}
#endif

private struct NoOpClient: DBClient {
    func setLocation(riderId: String, latitude: Double, longitude: Double, timestamp: Any, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

final class LocationSender: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var timer: Timer?
    private let dbClient: DBClient
    private let isPreview: Bool

    @Published var isSending = false
    @Published var statusMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var allowsBackgroundUpdates: Bool = false {
        didSet {
            // Only enable background updates when authorizedAlways
            let isAlways = authorizationStatus == .authorizedAlways
            let enable = allowsBackgroundUpdates && isAlways
            manager.allowsBackgroundLocationUpdates = enable
            if #available(iOS 11.0, *) {
                manager.showsBackgroundLocationIndicator = enable
            }
            if allowsBackgroundUpdates && !isAlways {
                // Inform the user and try to request Always authorization if possible
                statusMessage = "Background updates require 'Always' location access. Requesting…"
                requestAlwaysAuthorizationIfNeeded()
            }
        }
    }

    private var riderId: String {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid { return uid }
        #endif
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    init(preview: Bool = false) {
        isPreview = preview
        #if canImport(FirebaseFirestore)
        dbClient = preview ? NoOpClient() : FirestoreClient()
        #else
        dbClient = NoOpClient()
        #endif

        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = preview ? .authorizedWhenInUse : manager.authorizationStatus
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
        // Only attempt to request Always if WhenInUse is granted
        switch authorizationStatus {
        case .authorizedWhenInUse:
            if Thread.isMainThread {
                manager.requestAlwaysAuthorization()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.manager.requestAlwaysAuthorization()
                }
            }
        default:
            break
        }
    }

    func start() {
        if isPreview {
            isSending = true
            statusMessage = "Preview: sending every 10s."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            requestWhenInUseAuthorizationOnMain()
            statusMessage = "Requesting location permission…"
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
            return
        case .authorizedWhenInUse, .authorizedAlways:
            beginSending()
            if allowsBackgroundUpdates {
                requestAlwaysAuthorizationIfNeeded()
            }
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    private func beginSending() {
        guard !isSending else { return }
        // Ensure we don't enable background updates without Always authorization
        if allowsBackgroundUpdates && authorizationStatus != .authorizedAlways {
            statusMessage = "Background updates requested but not authorized for 'Always'. Requesting…"
            requestAlwaysAuthorizationIfNeeded()
        }
        manager.startUpdatingLocation()
        // Request a one-shot location to prime the first send quickly
        if CLLocationManager.locationServicesEnabled() {
            if manager.responds(to: #selector(CLLocationManager.requestLocation)) {
                manager.requestLocation()
            }
        }
        isSending = true
        statusMessage = "Started sending every 10s."
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        isSending = false
        timer?.invalidate()
        timer = nil
        if !isPreview {
            manager.stopUpdatingLocation()
        }
        statusMessage = "Stopped sending."
    }

    private func sendLocation(_ location: CLLocation) {
        let ts = DBFieldValue.serverTimestamp()
        dbClient.setLocation(
            riderId: riderId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: ts
        ) { [weak self] error in
            if let error = error {
                self?.statusMessage = "Failed to send: \(error.localizedDescription)"
            } else {
                self?.statusMessage = "Sent at \(Date().formatted(date: .omitted, time: .standard))"
            }
        }
    }

    private func sendCurrentLocation() {
        guard let location = manager.location else {
            statusMessage = "No location available yet."
            return
        }
        sendLocation(location)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // Update background flags based on current authorization
        let isAlways = authorizationStatus == .authorizedAlways
        let enable = allowsBackgroundUpdates && isAlways
        manager.allowsBackgroundLocationUpdates = enable
        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = enable
        }

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !isSending {
                beginSending()
            } else {
                manager.startUpdatingLocation()
            }
            if allowsBackgroundUpdates && authorizationStatus == .authorizedWhenInUse {
                statusMessage = "Background updates require 'Always' access. Requesting…"
                requestAlwaysAuthorizationIfNeeded()
            }
        case .denied, .restricted:
            statusMessage = "Location permission denied. Enable it in Settings."
            stop()
        case .notDetermined:
            // Waiting for user decision
            statusMessage = "Requesting location permission…"
        @unknown default:
            statusMessage = "Unknown authorization status."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        sendLocation(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Location error: \(error.localizedDescription)"
    }
}
