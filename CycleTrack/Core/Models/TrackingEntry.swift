//
//  TrackingEntry.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import Foundation
import CoreLocation

struct TrackingEntry: Codable, Identifiable {
    let id: String
    let riderId: String

    var status: RideStatus
    var sharingMode: SharingMode

    var lastLocation: TrackedLocation?
    var batteryLevel: Double?

    var startedAt: Date
    var endedAt: Date?
    var updatedAt: Date

    var viewerActiveUntil: Date?
    var lastViewedAt: Date?
}

enum RideStatus: String, Codable {
    case idle
    case riding
    case paused
    case ended
    case sos
}

enum SharingMode: String, Codable {
    case live        // viewer active
    case passive     // nobody watching
    case safetyOnly  // long inactivity
}
