import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://beu-backend-zxxo.onrender.com")!

    static var baseURLString: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
           let url = URL(string: configured.trimmingCharacters(in: .whitespacesAndNewlines)),
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url.absoluteString
        }

        return baseURL.absoluteString
    }
}
