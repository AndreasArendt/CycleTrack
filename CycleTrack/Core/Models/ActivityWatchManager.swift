import Combine
import CoreLocation
import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class ActivityWatchManager: ObservableObject {
    @Published private(set) var watchedActivities: [WatchedActivity] = []
    @Published var statusMessage: String?

    #if canImport(FirebaseFirestore)
    private var listeners: [String: ListenerRegistration] = [:]
    #endif

    deinit {
        #if canImport(FirebaseFirestore)
        listeners.keys.forEach { activityId in
            setCurrentUserWatcherActive(false, activityId: activityId)
        }
        listeners.values.forEach { $0.remove() }
        #endif
    }

    func watchActivity(id rawActivityId: String) {
        let invitation = parseInvitationToken(rawActivityId)
        guard let invitation else {
            statusMessage = "Paste a valid invitation token."
            return
        }

        #if canImport(FirebaseFirestore)
        guard listeners[invitation.activityId] == nil else {
            statusMessage = "Already watching this activity."
            return
        }

        setCurrentUserWatcherActive(true, activityId: invitation.activityId, invitationId: invitation.invitationId) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.statusMessage = "Invite unavailable: \(error.localizedDescription)"
                    return
                }

                self?.startListening(to: invitation.activityId)
            }
        }
        #else
        statusMessage = "Firebase activity watching is unavailable."
        #endif
    }

    private func startListening(to activityId: String) {
        #if canImport(FirebaseFirestore)
        watchedActivities.append(WatchedActivity(id: activityId, ownerUid: nil, status: "loading", coordinate: nil))

        listeners[activityId] = Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.statusMessage = "Failed to watch activity: \(error.localizedDescription)"
                        return
                    }

                    guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                        self?.statusMessage = "Activity not found."
                        return
                    }

                    self?.updateWatchedActivity(id: activityId, data: data)
                }
            }
        #endif
    }

    private func setCurrentUserWatcherActive(
        _ isActive: Bool,
        activityId: String,
        invitationId: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            completion?(ActivityRepositoryError.notAuthenticated)
            return
        }

        var data: [String: Any] = [
            "userId": user.uid,
            "displayName": "Watcher",
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let invitationId {
            data["invitationId"] = invitationId
        }

        Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .collection("watchers")
            .document(user.uid)
            .setData(data, merge: true) { error in
                completion?(error)
            }
        #else
        completion?(ActivityRepositoryError.unavailable)
        #endif
    }

    private func parseInvitationToken(_ rawToken: String) -> ActivityInvitationToken? {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = CharacterSet(charactersIn: "#:")
        let parts = token.components(separatedBy: separators)

        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty
        else {
            return nil
        }

        return ActivityInvitationToken(activityId: parts[0], invitationId: parts[1])
    }

    private func updateWatchedActivity(id: String, data: [String: Any]) {
        let status = data["status"] as? String ?? "unknown"
        let ownerUid = data["ownerUid"] as? String
        let coordinate = coordinate(from: data["lastLocation"] as? [String: Any])

        if let index = watchedActivities.firstIndex(where: { $0.id == id }) {
            watchedActivities[index] = WatchedActivity(id: id, ownerUid: ownerUid, status: status, coordinate: coordinate)
        } else {
            watchedActivities.append(WatchedActivity(id: id, ownerUid: ownerUid, status: status, coordinate: coordinate))
        }
    }

    private func coordinate(from data: [String: Any]?) -> CLLocationCoordinate2D? {
        guard let data,
              let latitude = data["latitude"] as? CLLocationDegrees,
              let longitude = data["longitude"] as? CLLocationDegrees
        else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct ActivityInvitationToken {
    let activityId: String
    let invitationId: String
}
