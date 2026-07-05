//
//  LoginView.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 05.07.26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

struct LoginView: View {
    // A closure to be called when login/continue flow finishes
    let onContinue: () -> Void

    // Loading state for sign-in action
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "bicycle.circle")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("CycleTrack")
                    .font(.largeTitle.bold())

                Text("Share your ride location.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Private invite links", systemImage: "link")
                Label("Optimized for minimal battery use", systemImage: "battery.75")
                Label("Live location updates", systemImage: "location")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: continueTapped) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(isLoading)

            Text("No account needed. You can start sharing your ride immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer().frame(height: 16)
        }
        .padding()
        .task {
            // Ensure Firebase is configured once and skip login if already authenticated
            configureFirebaseIfNeeded()
            if Auth.auth().currentUser != nil {
                // Already logged in -> skip
                onContinue()
            }
        }
    }
}

// MARK: - Private helpers
private extension LoginView {
    func configureFirebaseIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func continueTapped() {
        configureFirebaseIfNeeded()
        // If already signed in, just continue
        if Auth.auth().currentUser != nil {
            onContinue()
            return
        }

        isLoading = true
        Auth.auth().signInAnonymously { _, error in
            isLoading = false
            if let error = error {
                // In a real app, surface this to the user
                print("Anonymous sign-in failed: \(error.localizedDescription)")
                return
            }
            onContinue()
        }
    }
}

#Preview {
    LoginView(onContinue: { /* preview noop */ })
}
