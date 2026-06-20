//
//  CycleTrackApp.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import SwiftUI
import FirebaseCore
import CoreLocation
import FirebaseFirestore

final class LocationSender: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var timer: Timer?
    @Published var isSending = false
    private let db = Firestore.firestore()
    private var riderId: String { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        isSending = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.sendCurrentLocation()
            }
        }
    }

    func stop() {
        isSending = false
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
    }

    private func sendCurrentLocation() {
        guard let location = manager.location else { return }
        let data: [String: Any] = [
            "riderId": riderId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": FieldValue.serverTimestamp()
        ]
        db.collection("riderLocations").document(riderId).setData(data, merge: true)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && isSending {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) && isSending {
            manager.startUpdatingLocation()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        return true
    }
}

@main
struct CycleTrackApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            TrackingControlView()
        }
    }
}

struct TrackingControlView: View {
    @StateObject private var sender = LocationSender()

    var body: some View {
        VStack(spacing: 20) {
            Text(sender.isSending ? "Sending location every 10s" : "Not sending")
            Button(sender.isSending ? "Stop" : "Start") {
                if sender.isSending {
                    sender.stop()
                } else {
                    sender.start()
                }
            }
        }
        .padding()
    }
}
