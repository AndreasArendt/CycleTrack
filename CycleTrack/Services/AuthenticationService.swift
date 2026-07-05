import Foundation
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AuthenticationServiceError: LocalizedError {
    case authUnavailable
    case signOutFailed(Error)

    var errorDescription: String? {
        switch self {
        case .authUnavailable:
            return "FirebaseAuth is not linked to this target."
        case .signOutFailed(let error):
            return "Sign out failed: \(error.localizedDescription)"
        }
    }
}

final class AuthenticationService: ObservableObject {
    @Published private(set) var userId: String?
    @Published private(set) var isSignedIn = false
    @Published private(set) var providerName = "Not signed in"
    @Published var statusMessage: String?

    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    #endif

    init(previewUserId: String? = nil) {
        if let previewUserId {
            userId = previewUserId
            isSignedIn = true
            providerName = "Anonymous"
            statusMessage = "Signed in anonymously."
            return
        }

        #if canImport(FirebaseAuth)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.userId = user?.uid
                self?.isSignedIn = user != nil
                self?.providerName = Self.providerName(for: user)
            }
        }
        #endif
    }

    deinit {
        #if canImport(FirebaseAuth)
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
        #endif
    }

    func signInAnonymously() async throws -> String {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().signInAnonymously()
        await MainActor.run {
            userId = result.user.uid
            isSignedIn = true
            providerName = Self.providerName(for: result.user)
            statusMessage = "Signed in anonymously."
        }
        return result.user.uid
        #else
        throw AuthenticationServiceError.authUnavailable
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            userId = nil
            isSignedIn = false
            providerName = "Not signed in"
            statusMessage = "Signed out."
        } catch {
            throw AuthenticationServiceError.signOutFailed(error)
        }
        #else
        throw AuthenticationServiceError.authUnavailable
        #endif
    }

    private static func providerName(for user: User?) -> String {
        guard let user else { return "Not signed in" }
        if user.isAnonymous {
            return "Anonymous"
        }
        return "Firebase"
    }
}
