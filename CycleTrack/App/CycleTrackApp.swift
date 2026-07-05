//
//  CycleTrackApp.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct CycleTrackApp: App {
    // Track authentication state to decide which screen to show
    @State private var isAuthenticated: Bool

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Initialize auth state after Firebase is configured
        self._isAuthenticated = State(initialValue: Auth.auth().currentUser != nil)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    // Replace with your main/root screen after login
                    TrackingControlView()
                } else {
                    LoginView(onContinue: {
                        // When login completes, mark as authenticated
                        isAuthenticated = true
                    })
                }
            }
            .onAppear(perform: observeAuthChanges)
        }
    }

    private func observeAuthChanges() {
        // Keep UI in sync with auth state changes
        Auth.auth().addStateDidChangeListener { _, user in
            isAuthenticated = (user != nil)
        }
    }
}
