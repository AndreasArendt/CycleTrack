import SwiftUI
import MapKit

struct TrackingControlView: View {
    @StateObject private var auth = AuthenticationService()
    @State private var isSigningIn = false
    @State private var isWritingDummyEntry = false
    @State private var dummyWriteMessage: String?
    private let userPresenceRepository = UserPresenceRepository()
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @StateObject private var locationManager = LocationManager()
    
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

                LiveTrackingIslandView(locationManager: locationManager)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            userPresenceRepository.setCurrentUserActive(true)
            locationManager.requestLocationAuthorization()
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
