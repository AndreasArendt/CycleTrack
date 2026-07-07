import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class UserPresenceRepository {
    func setCurrentUserActive(_ isActive: Bool, completion: ((Error?) -> Void)? = nil) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            completion?(nil)
            return
        }

        var data: [String: Any] = [
            "id": user.uid,
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if isActive {
            data["lastOpenedAt"] = FieldValue.serverTimestamp()
        } else {
            data["lastSeenAt"] = FieldValue.serverTimestamp()
        }

        Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .setData(data, merge: true) { error in
                if let error {
                    print("User presence update failed: \(error.localizedDescription)")
                } else {
                    print("User presence updated: \(user.uid), isActive=\(isActive)")
                }

                completion?(error)
            }
        #else
        completion?(nil)
        #endif
    }
}
