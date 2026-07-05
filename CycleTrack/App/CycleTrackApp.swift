//
//  CycleTrackApp.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import SwiftUI
import FirebaseCore

@main
struct CycleTrackApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            TrackingControlView()
        }
    }
}
