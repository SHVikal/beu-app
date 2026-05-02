import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var baseline: Baseline?
    @Published private(set) var createdAt: Date?

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BeU", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("baseline.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let record = try? decoder.decode(BaselineRecord.self, from: data) else {
            baseline = nil
            createdAt = nil
            return
        }

        baseline = record.baseline
        createdAt = record.createdAt
    }

    func save(_ baseline: Baseline) {
        let record = BaselineRecord(
            baseline: baseline,
            createdAt: createdAt ?? Date()
        )
        if let data = try? encoder.encode(record) {
            try? data.write(to: fileURL, options: .atomic)
            self.baseline = baseline
            self.createdAt = record.createdAt
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        baseline = nil
        createdAt = nil
    }

    private struct BaselineRecord: Codable {
        let baseline: Baseline
        let createdAt: Date
    }
}
