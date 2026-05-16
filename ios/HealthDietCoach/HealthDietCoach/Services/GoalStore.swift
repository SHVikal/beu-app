import Foundation

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var goalConfig: GoalConfig?

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BeU", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("goal.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            self.goalConfig = nil
            return
        }

        if let goalConfig = try? decoder.decode(GoalConfig.self, from: data) {
            self.goalConfig = clamped(goalConfig)
            return
        }

        guard let legacy = try? decoder.decode(LegacyGoalConfig.self, from: data) else {
            self.goalConfig = nil
            return
        }

        let migrated = GoalConfig(
            goal: legacy.goal,
            targetWeightKg: legacy.targetWeightKg,
            timeline: migrateTimeline(from: legacy.timelineWeeks),
            customYears: 2
        )
        save(migrated)
    }

    func save(_ goalConfig: GoalConfig) {
        let goalConfig = clamped(goalConfig)
        if let data = try? encoder.encode(goalConfig) {
            try? data.write(to: fileURL, options: .atomic)
            self.goalConfig = goalConfig
        }
    }

    func restore(_ goalConfig: GoalConfig?) {
        guard let goalConfig else {
            try? FileManager.default.removeItem(at: fileURL)
            self.goalConfig = nil
            return
        }
        save(goalConfig)
    }

    private func clamped(_ goalConfig: GoalConfig) -> GoalConfig {
        var copy = goalConfig
        copy.customYears = min(max(copy.customYears, 1), 10)
        return copy
    }

    private func migrateTimeline(from legacyWeeks: Int?) -> TimelinePreset {
        switch legacyWeeks {
        case 4:
            return .oneMonth
        case 8, 12:
            return .threeMonths
        default:
            return .threeMonths
        }
    }

    private struct LegacyGoalConfig: Codable {
        var goal: Goal
        var targetWeightKg: Int?
        var timelineWeeks: Int?
    }
}

@MainActor
final class WaterProgressStore: ObservableObject {
    @Published private(set) var dailyHydrationMl: Int = 0

    private let defaults: UserDefaults
    private let dateFormatter = ISODateOnlyFormatter.shared
    private let maxHydrationMl = 4000
    private let keyPrefix = "beu_water_"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadToday()
    }

    var litresToday: Double {
        Double(dailyHydrationMl) / 1000
    }

    func loadToday() {
        dailyHydrationMl = min(max(defaults.integer(forKey: key(for: Date())), 0), maxHydrationMl)
    }

    @discardableResult
    func add100Millilitres() -> Bool {
        guard dailyHydrationMl < maxHydrationMl else { return false }
        dailyHydrationMl = min(dailyHydrationMl + 100, maxHydrationMl)
        defaults.set(dailyHydrationMl, forKey: key(for: Date()))
        return true
    }

    func overwriteToday(millilitres: Int) {
        dailyHydrationMl = min(max(millilitres, 0), maxHydrationMl)
        defaults.set(dailyHydrationMl, forKey: key(for: Date()))
    }

    private func key(for date: Date) -> String {
        keyPrefix + dateFormatter.string(from: date)
    }

    func allEntries() -> [StoredWaterProgressEntry] {
        defaults.dictionaryRepresentation()
            .compactMap { key, value -> StoredWaterProgressEntry? in
                guard key.hasPrefix(keyPrefix) else { return nil }
                let date = String(key.dropFirst(keyPrefix.count))
                let millilitres = min(max((value as? Int) ?? 0, 0), maxHydrationMl)
                return StoredWaterProgressEntry(date: date, millilitres: millilitres)
            }
            .sorted { $0.date < $1.date }
    }

    func replaceAll(entries: [StoredWaterProgressEntry]) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }

        for entry in entries {
            defaults.set(min(max(entry.millilitres, 0), maxHydrationMl), forKey: keyPrefix + entry.date)
        }

        loadToday()
    }
}

struct StoredWaterProgressEntry: Codable, Equatable, Identifiable {
    let date: String
    let millilitres: Int

    var id: String { date }
}

enum ISODateOnlyFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
