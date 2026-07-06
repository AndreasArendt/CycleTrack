import CoreLocation
import Foundation
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class LocationRepository {
    private let isPreview: Bool

    init(preview: Bool = false) {
        isPreview = preview
    }

    func saveCurrentRiderLocation(_ location: CLLocation, completion: @escaping (Error?) -> Void) {
        guard !isPreview else {
            completion(nil)
            return
        }

        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "riderId": riderId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("riderLocations")
            .document(riderId)
            .setData(data, merge: true) { error in
                completion(error)
            }
        #else
        completion(nil)
        #endif
    }

    private var riderId: String {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        #endif

        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}
