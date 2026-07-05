//
//  TrackingEntry.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import Foundation

// Minimal model to create and encode a dummy entry into Firestore
struct TrackingEntry: Codable, Identifiable {
    let id: String
    let riderId: String

    // Keep only a minimal status field for now
    var status: RideStatus

    // Timestamps helpful for sorting/queries
    var createdAt: Date
    var updatedAt: Date

    // Factory for a dummy entry
    static func dummy(riderId: String = "dummy-rider", now: Date = Date()) -> TrackingEntry {
        return TrackingEntry(
            id: UUID().uuidString,
            riderId: riderId,
            status: .idle,
            createdAt: now,
            updatedAt: now
        )
    }
}

enum RideStatus: String, Codable {
    case idle
}
