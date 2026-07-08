import SwiftUI
import MapKit

struct TrackingControlView: View {
    @StateObject private var auth = AuthenticationService()
    @State private var isSigningIn = false
    @State private var isWritingDummyEntry = false
    @State private var dummyWriteMessage: String?
    @State private var isAddingActivity = false
    @State private var activityIdToWatch = ""
    private let userPresenceRepository = UserPresenceRepository()
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @StateObject private var locationManager = LocationManager()
    @StateObject private var activityWatchManager = ActivityWatchManager()
    
    @Namespace private var mapScope
    
    init(
        auth: AuthenticationService = AuthenticationService(),
        locationManager: LocationManager = LocationManager()
    ) {
        _auth = StateObject(wrappedValue: auth)
        _locationManager = StateObject(wrappedValue: locationManager)
    }
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition, scope: mapScope) {
                UserAnnotation()

                ForEach(activityWatchManager.watchedActivities) { activity in
                    if let coordinate = activity.coordinate {
                        Marker("Rider", systemImage: "figure.outdoor.cycle", coordinate: coordinate)
                            .tint(activity.status == "live" ? .green : .orange)
                    }
                }
            }
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()
            .mapScope(mapScope)

            VStack(spacing: 0) {
//                HStack {
//                    Spacer()
//                    menuButton
//                    locationButton
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, 12)

                Spacer()

                LiveTrackingIslandView(
                    locationManager: locationManager,
                    watchedActivities: activityWatchManager.watchedActivities,
                    watchingStatusMessage: activityWatchManager.statusMessage
                ) {
                    isAddingActivity = true
                }
                    .padding(.horizontal, 16)
            }
        }
        .onAppear {
            userPresenceRepository.setCurrentUserActive(true)
            locationManager.requestLocationAuthorization()
        }
        .alert("Add Activity", isPresented: $isAddingActivity) {
            TextField("Invitation Token", text: $activityIdToWatch)

            Button("Cancel", role: .cancel) {
                activityIdToWatch = ""
            }

            Button("Watch") {
                activityWatchManager.watchActivity(id: activityIdToWatch)
                activityIdToWatch = ""
            }
        } message: {
            Text("Paste a shared invitation token to see that rider on your map.")
        }
    }

    private var locationButton: some View
    {
        HStack {
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .userLocation(
                        followsHeading: false,
                        fallback: .automatic
                    )}
            } label: {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.blue, in: Circle())
                    .shadow(radius: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
        
    private func signOut() {
        do {
            try auth.signOut()
            dummyWriteMessage = nil
        } catch {
            auth.statusMessage = error.localizedDescription
        }
    }
    
    private func writeDummyEntry() {
        isWritingDummyEntry = true
        dummyWriteMessage = "Writing dummy entry..."
        
        Task {
            do {
                let documentId = try await FirebaseService.shared.writeDummyTrackingEntry()
                dummyWriteMessage = "Wrote trackingEntries/\(documentId)"
            } catch {
                dummyWriteMessage = "Dummy write failed: \(error.localizedDescription)"
            }
            
            isWritingDummyEntry = false
        }
    }
}

#Preview {
    TrackingControlView(
        auth: AuthenticationService(previewUserId: "preview-user"),
        locationManager: LocationManager(preview: true)
    )
}
