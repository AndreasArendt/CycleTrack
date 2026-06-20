//
//  TrackedLocation.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//
import Foundation
import CoreLocation

struct TrackedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let speed: Double?
    let course: Double?
    let timestamp: Date

    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
        self.timestamp = location.timestamp
    }
}
