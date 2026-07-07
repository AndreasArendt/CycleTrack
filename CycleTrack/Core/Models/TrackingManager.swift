//
//  TrackingManager.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 06.07.26.
//

import SwiftUI
import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class TrackingManager: ObservableObject {
    @Published var watchers: [Watcher] = []

    #if canImport(FirebaseFirestore)
    private var watcherListener: ListenerRegistration?
    private var observedActivityId: String?
    #endif

    deinit {
        #if canImport(FirebaseFirestore)
        watcherListener?.remove()
        #endif
    }

    func observeWatchers(activityId: String?) {
        #if canImport(FirebaseFirestore)
        watcherListener?.remove()
        watcherListener = nil

        guard let activityId else {
            observedActivityId = nil
            watchers = []
            return
        }

        observedActivityId = activityId

        watcherListener = Firestore.firestore()
            .collection("activities")
            .document(activityId)
            .collection("watchers")
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.watchers = []
                        return
                    }

                    self?.watchers = snapshot?.documents.map { document in
                        let data = document.data()
                        let name = data["displayName"] as? String ?? "Watcher"
                        let isActive = data["isActive"] as? Bool ?? false
                        let invitationId = data["invitationId"] as? String

                        return Watcher(id: document.documentID, name: name, isActive: isActive, invitationId: invitationId)
                    } ?? []
                }
            }
        #else
        watchers = []
        #endif
    }

    func removeWatcher(_ watcher: Watcher) {
        #if canImport(FirebaseFirestore)
        guard let observedActivityId else { return }

        let database = Firestore.firestore()
        let watcherReference = database
            .collection("activities")
            .document(observedActivityId)
            .collection("watchers")
            .document(watcher.id)

        let batch = database.batch()

        if let invitationId = watcher.invitationId {
            let invitationReference = database
                .collection("activities")
                .document(observedActivityId)
                .collection("invitations")
                .document(invitationId)

            batch.setData([
                "revokedByWatcherId": watcher.id,
                "revokedAt": FieldValue.serverTimestamp()
            ], forDocument: invitationReference, merge: true)
        }

        batch.deleteDocument(watcherReference)

        batch.commit { error in
            if let error {
                print("Watcher removal failed: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    
}
