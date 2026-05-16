import Foundation

final class AppStateSyncService {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetch(userId: String) async throws -> AppStateSnapshotPayload? {
        do {
            let envelope = try await apiClient.fetchAppState(userId: userId)
            return envelope.payload
        } catch let error as APIError {
            if case .server(let message) = error, message.localizedCaseInsensitiveContains("not found") {
                return nil
            }
            throw error
        }
    }

    @discardableResult
    func save(userId: String, payload: AppStateSnapshotPayload) async throws -> RemoteAppStateEnvelope {
        try await apiClient.saveAppState(userId: userId, payload: payload)
    }
}
