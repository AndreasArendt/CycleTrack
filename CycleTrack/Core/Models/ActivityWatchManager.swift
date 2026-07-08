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
    private var watcherListeners: [String: ListenerRegistration] = [:]
    #endif

    deinit {
        #if canImport(FirebaseFirestore)
        listeners.keys.forEach { activityId in
            setCurrentUserWatcherActive(false, activityId: activityId)
        }
        listeners.values.forEach { $0.remove() }
        watcherListeners.values.forEach { $0.remove() }
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
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            statusMessage = ActivityRepositoryError.notAuthenticated.localizedDescription
            return
        }

        watchedActivities.append(WatchedActivity(id: activityId, ownerUid: nil, status: "loading", coordinate: nil))

        watcherListeners[activityId] = Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .collection("watchers")
            .document(user.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.removeWatchedActivity(id: activityId)
                        self?.statusMessage = "Stopped watching: \(error.localizedDescription)"
                        return
                    }

                    guard let snapshot, snapshot.exists else {
                        self?.removeWatchedActivity(id: activityId)
                        self?.statusMessage = "You were removed from this activity."
                        return
                    }
                }
            }

        listeners[activityId] = Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.removeWatchedActivity(id: activityId)
                        self?.statusMessage = "Stopped watching: \(error.localizedDescription)"
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
        let candidates = [token] + token.components(separatedBy: .whitespacesAndNewlines)

        for candidate in candidates {
            if let invitation = parseCompactInvitationToken(candidate, separator: "#") {
                return invitation
            }
        }

        guard !token.contains(" ") else { return nil }

        return parseCompactInvitationToken(token, separator: ":")
    }

    private func parseCompactInvitationToken(_ token: String, separator: Character) -> ActivityInvitationToken? {
        let parts = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: separator, omittingEmptySubsequences: true)

        guard parts.count == 2 else {
            return nil
        }

        return ActivityInvitationToken(activityId: String(parts[0]), invitationId: String(parts[1]))
    }

    private func removeWatchedActivity(id: String) {
        #if canImport(FirebaseFirestore)
        listeners[id]?.remove()
        listeners[id] = nil
        watcherListeners[id]?.remove()
        watcherListeners[id] = nil
        #endif

        watchedActivities.removeAll { $0.id == id }
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
