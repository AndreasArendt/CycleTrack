import CoreLocation
import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class ActivityRepository {
    private let isPreview: Bool

    init(preview: Bool = false) {
        isPreview = preview
    }

    func createLiveActivity(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isPreview else {
            completion(.success(UUID().uuidString))
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let ownerUid = Auth.auth().currentUser?.uid else {
            completion(.failure(ActivityRepositoryError.notAuthenticated))
            return
        }

        let activityRef = Firestore.firestore().collection("activities").document()
        let data: [String: Any] = [
            "id": activityRef.documentID,
            "ownerUid": ownerUid,
            "status": "live",
            "startedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        activityRef.setData(data) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(activityRef.documentID))
            }
        }
        #else
        completion(.failure(ActivityRepositoryError.unavailable))
        #endif
    }

    func updateLiveActivityLocation(activityId: String, location: CLLocation, completion: @escaping (Error?) -> Void) {
        guard !isPreview else {
            completion(nil)
            return
        }

        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "lastLocation": [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "timestamp": FieldValue.serverTimestamp()
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .setData(data, merge: true) { error in
                completion(error)
            }
        #else
        completion(ActivityRepositoryError.unavailable)
        #endif
    }

    func updateActivityStatus(activityId: String, status: ActivityStatus, completion: ((Error?) -> Void)? = nil) {
        guard !isPreview else {
            completion?(nil)
            return
        }

        #if canImport(FirebaseFirestore)
        var data: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if status == .ended {
            data["endedAt"] = FieldValue.serverTimestamp()
        }

        Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .setData(data, merge: true) { error in
                completion?(error)
            }
        #else
        completion?(ActivityRepositoryError.unavailable)
        #endif
    }

    func createInvitation(activityId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !isPreview else {
            completion(.success("\(activityId)#\(UUID().uuidString)"))
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let ownerUid = Auth.auth().currentUser?.uid else {
            completion(.failure(ActivityRepositoryError.notAuthenticated))
            return
        }

        let invitationRef = Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .collection("invitations")
            .document()

        let data: [String: Any] = [
            "id": invitationRef.documentID,
            "activityId": activityId,
            "createdBy": ownerUid,
            "createdAt": FieldValue.serverTimestamp()
        ]

        invitationRef.setData(data) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success("\(activityId)#\(invitationRef.documentID)"))
            }
        }
        #else
        completion(.failure(ActivityRepositoryError.unavailable))
        #endif
    }
}

enum ActivityStatus: String {
    case live
    case paused
    case ended
}

enum ActivityRepositoryError: LocalizedError {
    case notAuthenticated
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in before starting a live activity."
        case .unavailable:
            return "Firebase activity storage is unavailable."
        }
    }
}
