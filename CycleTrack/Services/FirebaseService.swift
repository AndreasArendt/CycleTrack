//
//  FirebaseService.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 20.06.26.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum FirebaseServiceError: LocalizedError {
    case firebaseNotConfigured
    case authUnavailable
    case firestoreUnavailable
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured. Check that GoogleService-Info.plist is included in the app target."
        case .authUnavailable:
            return "FirebaseAuth is not linked to this target."
        case .firestoreUnavailable:
            return "FirebaseFirestore is not linked to this target."
        case .notAuthenticated:
            return "Sign in before writing to Firestore."
        }
    }
}

final class FirebaseService {
    static let shared = FirebaseService()

    private init() {}

    func writeDummyTrackingEntry() async throws -> String {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else {
            throw FirebaseServiceError.firebaseNotConfigured
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseServiceError.notAuthenticated
        }

        let entry = TrackingEntry.dummy(riderId: userId)
        let data: [String: Any] = [
            "id": entry.id,
            "riderId": entry.riderId,
            "ownerUid": userId,
            "status": entry.status.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "clientCreatedAt": entry.createdAt,
            "source": "ios-debug-button"
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore()
                .collection("trackingEntries")
                .document(entry.id)
                .setData(data) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }

        return entry.id
        #elseif !canImport(FirebaseAuth)
        throw FirebaseServiceError.authUnavailable
        #else
        throw FirebaseServiceError.firestoreUnavailable
        #endif
    }
}
