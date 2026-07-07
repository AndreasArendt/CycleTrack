import CoreLocation
import Foundation

struct WatchedActivity: Identifiable {
    let id: String
    var ownerUid: String?
    var status: String
    var coordinate: CLLocationCoordinate2D?
}
