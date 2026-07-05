import Foundation

enum DummyWriter {
    static func writeDummy(completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let documentId = try await FirebaseService.shared.writeDummyTrackingEntry()
                await MainActor.run {
                    completion(.success(documentId))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
