import Foundation

enum ReadinessStatus: String, Codable {
    case high
    case good
    case moderate
    case low
    case limitedData = "limited_data"

    var displayTitle: String {
        switch self {
        case .high: return "High"
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .low: return "Low"
        case .limitedData: return "Limited data"
        }
    }
}

struct Readiness: Codable, Equatable {
    var score: Int
    var status: ReadinessStatus
    var oneLineMessage: String
    var contributingFactors: [String]
    var usedDefaultSleep: Bool
    var availableSignals: [String]
    var missingSignals: [String]
}
