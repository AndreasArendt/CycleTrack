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
    @Environment(\.scenePhase) private var scenePhase
    // Track authentication state to decide which screen to show
    @State private var isAuthenticated: Bool
    private let userPresenceRepository = UserPresenceRepository()

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
                        markCurrentUserActive()
                    })
                }
            }
            .onAppear(perform: observeAuthChanges)
            .onChange(of: scenePhase) { _, newPhase in
                updateUserPresence(for: newPhase)
            }
        }
    }

    private func observeAuthChanges() {
        // Keep UI in sync with auth state changes
        Auth.auth().addStateDidChangeListener { _, user in
            isAuthenticated = (user != nil)

            if user != nil {
                markCurrentUserActive()
            }
        }
    }

    private func markCurrentUserActive() {
        userPresenceRepository.setCurrentUserActive(true)
    }

    private func updateUserPresence(for scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            markCurrentUserActive()
        case .background:
            userPresenceRepository.setCurrentUserActive(false)
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
